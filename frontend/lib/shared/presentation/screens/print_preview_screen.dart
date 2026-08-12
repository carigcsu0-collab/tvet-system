// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';

class _PdfFontSet {
  final pw.Font regular;
  final pw.Font? bold;
  final pw.Font? italic;
  final pw.Font? boldItalic;

  _PdfFontSet({required this.regular, this.bold, this.italic, this.boldItalic});

  pw.TextStyle style({
    required double fontSize,
    PdfColor color = PdfColors.black,
    pw.FontWeight? fontWeight,
    pw.FontStyle? fontStyle,
    double? height,
    pw.TextDecoration? decoration,
    PdfColor? decorationColor,
  }) {
    return pw.TextStyle(
      fontNormal: regular,
      fontBold: bold ?? regular,
      fontItalic: italic ?? regular,
      fontBoldItalic: boldItalic ?? bold ?? regular,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }
}

class _PdfFonts {
  final _PdfFontSet centuryGothic;
  final _PdfFontSet brushScriptMt;
  final _PdfFontSet monotypeCorsiva;
  final _PdfFontSet constantia;

  _PdfFonts({
    required this.centuryGothic,
    required this.brushScriptMt,
    required this.monotypeCorsiva,
    required this.constantia,
  });

  static Future<_PdfFonts> load() async {
    Future<pw.Font> loadFont(String path) async {
      final data = await rootBundle.load(path);
      return pw.Font.ttf(data);
    }

    final centuryGothicRegular = await loadFont('assets/fonts/century_gothic.ttf');
    final centuryGothicBold = await loadFont('assets/fonts/century_gothic_bold.ttf');
    final centuryGothicItalic = await loadFont('assets/fonts/century_gothic_italic.ttf');
    final centuryGothicBoldItalic = await loadFont('assets/fonts/century_gothic_bolditalic.ttf');
    final brushScriptMt = await loadFont('assets/fonts/brush_script_mt.ttf');
    final monotypeCorsiva = await loadFont('assets/fonts/monotype_corsiva.ttf');
    final constantiaRegular = await loadFont('assets/fonts/constantia.ttf');
    final constantiaBold = await loadFont('assets/fonts/constantia_bold.ttf');
    final constantiaItalic = await loadFont('assets/fonts/constantia_italic.ttf');
    final constantiaBoldItalic = await loadFont('assets/fonts/constantia_bolditalic.ttf');

    return _PdfFonts(
      centuryGothic: _PdfFontSet(
        regular: centuryGothicRegular,
        bold: centuryGothicBold,
        italic: centuryGothicItalic,
        boldItalic: centuryGothicBoldItalic,
      ),
      brushScriptMt: _PdfFontSet(regular: brushScriptMt),
      monotypeCorsiva: _PdfFontSet(regular: monotypeCorsiva),
      constantia: _PdfFontSet(
        regular: constantiaRegular,
        bold: constantiaBold,
        italic: constantiaItalic,
        boldItalic: constantiaBoldItalic,
      ),
    );
  }
}

class PrintPreviewScreen extends StatefulWidget {
  final String code;

  const PrintPreviewScreen({super.key, required this.code});

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  final _previewKey = GlobalKey();
  Map<String, dynamic>? _record;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  String _selectedPageSize = 'A4';

  static const _mm = PdfPageFormat.mm;
  static const _inch = PdfPageFormat.inch;
  static const _paperSizes = <String, PdfPageFormat>{
    'A0': PdfPageFormat(841 * _mm, 1189 * _mm),
    'A1': PdfPageFormat(594 * _mm, 841 * _mm),
    'A2': PdfPageFormat(420 * _mm, 594 * _mm),
    'A3': PdfPageFormat(297 * _mm, 420 * _mm),
    'A4': PdfPageFormat.a4,
    'A5': PdfPageFormat(148 * _mm, 210 * _mm),
    'A6': PdfPageFormat(105 * _mm, 148 * _mm),
    'B0': PdfPageFormat(1000 * _mm, 1414 * _mm),
    'B1': PdfPageFormat(707 * _mm, 1000 * _mm),
    'B2': PdfPageFormat(500 * _mm, 707 * _mm),
    'B3': PdfPageFormat(353 * _mm, 500 * _mm),
    'B4': PdfPageFormat(250 * _mm, 353 * _mm),
    'B5': PdfPageFormat(176 * _mm, 250 * _mm),
    'B6': PdfPageFormat(125 * _mm, 176 * _mm),
    'Letter': PdfPageFormat.letter,
    'Legal': PdfPageFormat.legal,
    'Folio': PdfPageFormat(8.5 * _inch, 13 * _inch),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/documents/${widget.code}');
      if (!mounted) return;
      setState(() {
        _record = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Uint8List> _captureImage({double pixelRatio = 3.0}) async {
    final boundary = _previewKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Unable to capture preview');
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Unable to encode image');
    return byteData.buffer.asUint8List();
  }

  Future<Uint8List> _buildPdfBytes({PdfPageFormat? format}) async {
    final pageFormat = format ?? PdfPageFormat.a4;
    final pdf = pw.Document();

    final fonts = await _PdfFonts.load();

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/csu_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final payload = (_record!['payload'] as Map<String, dynamic>?) ?? {};
    final type = _record!['document_type'] as Map<String, dynamic>?;
    final slug = type?['slug']?.toString() ?? '';
    final code = _record!['code']?.toString() ?? '';

    const inch = PdfPageFormat.inch;

    // Load sidebar and bottom art images
    pw.MemoryImage? sidebarImage;
    pw.MemoryImage? buildingImage;
    pw.MemoryImage? eagleImage;
    try {
      final sbBytes = await rootBundle.load('assets/side_bar.png');
      sidebarImage = pw.MemoryImage(sbBytes.buffer.asUint8List());
    } catch (_) {}
    try {
      final bBytes = await rootBundle.load('assets/csu_building.png');
      buildingImage = pw.MemoryImage(bBytes.buffer.asUint8List());
    } catch (_) {}
    try {
      final eBytes = await rootBundle.load('assets/csu_eagle.png');
      eagleImage = pw.MemoryImage(eBytes.buffer.asUint8List());
    } catch (_) {}

    // Sidebar width = 20% of page width (matching on-screen preview)
    final sidebarWidth = pageFormat.width * 0.20;
    const topMargin = 0.5 * inch;
    const rightMargin = 0.5 * inch;
    const bottomMargin = 1.5 * inch;
    final contentLeftMargin = sidebarWidth + 0.5 * inch;

    // NOTE: pw.PageTheme.buildBackground paints its content relative to the
    // margin box (offset by margin.left / margin.bottom), not the true page
    // origin (0,0). To make the sidebar bleed to the true left edge of the
    // page (instead of rendering at x = contentLeftMargin, which overlaps the
    // body content), we offset it left/top/bottom by the negative margin
    // amounts so it lands at the actual page edges.
    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.fromLTRB(contentLeftMargin, topMargin, rightMargin, bottomMargin),
      buildBackground: (context) => pw.Stack(
        overflow: pw.Overflow.visible,
        children: [
          // Sidebar - full height, true left edge of the page
          pw.Positioned(
            left: -contentLeftMargin,
            top: -topMargin,
            bottom: -bottomMargin,
            child: pw.SizedBox(
              width: sidebarWidth,
              child: _buildPdfSidebar(sidebarImage, fonts),
            ),
          ),
          // Bottom art - true bottom-right corner of the page
          if (buildingImage != null)
            pw.Positioned(
              right: -rightMargin,
              bottom: -bottomMargin,
              child: _buildPdfBottomArt(buildingImage, eagleImage, sidebarWidth),
            ),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => pw.Column(
          children: [
            _buildPdfHeader(logoImage, fonts),
            pw.Divider(thickness: 0.8, color: PdfColors.grey),
            pw.SizedBox(height: 14),
          ],
        ),
        footer: (context) => _buildPdfFooter(fonts),
        build: (context) => [
          if (slug == 'certificate-of-appearance')
            ..._buildPdfCertificateContent(payload, code, fonts)
          else
            ..._buildPdfLetterContent(payload, code, fonts),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSidebar(pw.MemoryImage? sidebarImage, _PdfFonts fonts) {
    final bodyStyle = fonts.monotypeCorsiva.style(fontSize: 7, height: 1.3, fontStyle: pw.FontStyle.italic);
    final headingStyle = fonts.monotypeCorsiva.style(fontSize: 8, fontWeight: pw.FontWeight.bold, height: 1.3, fontStyle: pw.FontStyle.italic);
    final groupStyle = fonts.monotypeCorsiva.style(fontSize: 7.5, fontWeight: pw.FontWeight.bold, height: 1.3, fontStyle: pw.FontStyle.italic);

    return pw.Stack(
      children: [
        if (sidebarImage != null)
          pw.Positioned.fill(
            child: pw.Image(sidebarImage, fit: pw.BoxFit.fill),
          ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(10, 50, 22, 50),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('VISION', style: headingStyle),
              pw.SizedBox(height: 2),
              pw.Text(
                'CSU is a University with global stature in the arts, culture, agriculture and fisheries, the sciences as well as technological and professional fields.',
                style: bodyStyle,
              ),
              pw.SizedBox(height: 6),
              pw.Text('MISSION', style: headingStyle),
              pw.SizedBox(height: 2),
              pw.Text(
                'Cagayan State University shall produce globally competent graduates through excellent instruction, innovative and creative research, responsive public service and productive industry and community engagement.',
                style: bodyStyle,
              ),
              pw.SizedBox(height: 6),
              pw.Text('CORE VALUES', style: headingStyle),
              pw.SizedBox(height: 2),
              pw.Text('Competence', style: groupStyle),
              pw.Text('- Critical Thinker', style: bodyStyle),
              pw.Text('- Creative Problem -Solver', style: bodyStyle),
              pw.Text('- Competitive Performer: Nationally, Regionally and Globally.', style: bodyStyle),
              pw.SizedBox(height: 4),
              pw.Text('Social Responsibility', style: groupStyle),
              pw.Text('- Sensitive to Ethical Demands', style: bodyStyle),
              pw.Text('- Steward of the Environment for Future Generations', style: bodyStyle),
              pw.Text('- Social Justice and Economic Equity Advocate.', style: bodyStyle),
              pw.SizedBox(height: 4),
              pw.Text('Unifying Presence', style: groupStyle),
              pw.Text('- Uniting Theory and Practice', style: bodyStyle),
              pw.Text('- Uniting Strata of Society', style: bodyStyle),
              pw.Text('- Unifying the Nation, the ASEAN Region and the world', style: bodyStyle),
              pw.Text('- Uniting the University and the community.', style: bodyStyle),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfBottomArt(pw.MemoryImage buildingImage, pw.MemoryImage? eagleImage, double sidebarWidth) {
    final scale = sidebarWidth / 89.25; // 89.25pt = 119.4px in points
    return pw.SizedBox(
      width: 127.5 * scale,
      height: 67.5 * scale,
      child: pw.Stack(
        children: [
          pw.Positioned(
            right: 6 * scale,
            bottom: 4.5 * scale,
            child: pw.Image(buildingImage, width: 88.5 * scale),
          ),
          if (eagleImage != null)
            pw.Positioned(
              right: 3 * scale,
              bottom: 30 * scale,
              child: pw.Transform.rotate(
                angle: -0.35,
                child: pw.Image(eagleImage, width: 25.5 * scale),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeader(pw.MemoryImage? logoImage, _PdfFonts fonts) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) pw.Image(logoImage, height: 58),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Republic of the Philippines',
                      style: fonts.centuryGothic.style(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text('CAGAYAN STATE UNIVERSITY',
                      style: fonts.centuryGothic.style(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800)),
                  pw.Text('CARIG CAMPUS',
                      style: fonts.centuryGothic.style(fontSize: 11, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text('Carig Sur, Tuguegarao City, Cagayan',
                      style: fonts.centuryGothic.style(fontSize: 8.5, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text('Campus TVET Office',
              style: fonts.brushScriptMt.style(
                  fontSize: 17,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey500)),
        ),
      ],
    );
  }

  pw.Widget _buildPdfFooter(_PdfFonts fonts) {
    final base = fonts.constantia.style(fontSize: 9, color: PdfColors.black);
    final link = fonts.constantia.style(
      fontSize: 9,
      color: const PdfColor.fromInt(0xFF0462C1),
      decoration: pw.TextDecoration.underline,
      decorationColor: const PdfColor.fromInt(0xFF0462C1),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              style: base,
              children: [
                const pw.TextSpan(text: 'Website: '),
                pw.TextSpan(text: 'http://www.csucarig.edu.ph', style: link),
              ],
            ),
          ),
          pw.RichText(
            text: pw.TextSpan(
              style: base,
              children: [
                const pw.TextSpan(text: 'Email Address: '),
                pw.TextSpan(text: 'tvet@csucarig.edu.ph', style: link),
              ],
            ),
          ),
          pw.Text('Local No. 042', style: base),
        ],
      ),
    );
  }

  List<pw.Widget> _buildPdfLetterContent(Map<String, dynamic> payload, String code, _PdfFonts fonts) {
    final date = payload['date']?.toString() ??
        payload['issued_at']?.toString() ??
        '';
    final to = payload['to']?.toString() ??
        payload['recipient']?.toString() ??
        '';
    final toDetail = payload['organization']?.toString() ??
        payload['recipient_office']?.toString() ??
        '';
    final address = payload['address']?.toString() ??
        payload['recipient_address']?.toString() ??
        '';
    final from = payload['from']?.toString() ??
        payload['campus_name']?.toString() ??
        '';
    final subject = payload['subject']?.toString() ?? '';
    final body = payload['body']?.toString() ?? '';
    final table = payload['table'] as List<dynamic>?;
    final tableColumns = payload['tableColumns'] as List<dynamic>?;
    final coordinator = payload['coordinatorName']?.toString() ??
        payload['coordinator_name']?.toString() ??
        '';
    final coordinatorTitle = payload['coordinatorTitle']?.toString() ?? 'Campus TVET Coordinator';
    final greetings = payload['greetings']?.toString() ?? 'Sir:';
    final footerBody = payload['footerBody']?.toString() ?? '';

    final bodyStyle = fonts.centuryGothic.style(fontSize: 12, color: PdfColors.black, height: 1.6);
    final boldStyle = fonts.centuryGothic.style(
        fontSize: 12, color: PdfColors.black, height: 1.6, fontWeight: pw.FontWeight.bold);

    return [
      pw.Text(code,
          style: fonts.centuryGothic.style(
              fontSize: 12, color: PdfColors.green, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      if (date.isNotEmpty) pw.Text(date, style: bodyStyle),
      pw.SizedBox(height: 20),
      if (to.isNotEmpty) pw.Text(to, style: boldStyle),
      if (toDetail.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(toDetail, style: bodyStyle),
      ],
      if (address.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(address, style: bodyStyle),
      ],
      if (from.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        pw.Text('Thru: $from', style: boldStyle),
      ],
      pw.SizedBox(height: 20),
      if (subject.isNotEmpty) pw.Text('Subject: $subject', style: boldStyle),
      pw.SizedBox(height: 16),
      pw.Text(greetings, style: bodyStyle),
      pw.SizedBox(height: 4),
      pw.Text('Greetings!',
          style: fonts.centuryGothic.style(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.black)),
      pw.SizedBox(height: 12),
      pw.Text(body, style: bodyStyle, textAlign: pw.TextAlign.justify),
      if (table != null && table.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        _buildPdfTable(table, tableColumns),
      ],
      if (footerBody.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        pw.Text(footerBody, style: bodyStyle, textAlign: pw.TextAlign.justify),
      ],
      pw.SizedBox(height: 32),
      pw.Text('Very respectfully yours,', style: bodyStyle),
      pw.SizedBox(height: 2 * PdfPageFormat.mm),
      pw.Text(coordinator, style: boldStyle),
      pw.Text(coordinatorTitle,
          style: fonts.centuryGothic.style(fontSize: 11, color: PdfColors.black)),
      pw.Text('Cagayan State University',
          style: fonts.centuryGothic.style(fontSize: 11, color: PdfColors.black)),
    ];
  }

  List<pw.Widget> _buildPdfCertificateContent(Map<String, dynamic> payload, String code, _PdfFonts fonts) {
    final recipient = payload['recipient_name']?.toString() ?? '';
    final office = payload['recipient_office']?.toString() ?? '';
    final campus = payload['campus_name']?.toString() ?? '';
    final appearanceDate = payload['appearance_date']?.toString() ?? '';
    final purpose = payload['purpose']?.toString() ?? '';
    final day = payload['issued_day']?.toString() ?? '';
    final monthYear = payload['issued_month_year']?.toString() ?? '';
    final coordinator = payload['coordinatorName']?.toString() ??
        payload['coordinator_name']?.toString() ??
        '';
    final coordinatorTitle = payload['coordinatorTitle']?.toString() ?? 'TVET Coordinator';

    final bodyStyle = fonts.centuryGothic.style(fontSize: 12, color: PdfColors.black, height: 1.6);

    return [
      pw.Text(code,
          style: fonts.centuryGothic.style(
              fontSize: 12, color: PdfColors.green, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      pw.Center(
        child: pw.Text('CERTIFICATE OF APPEARANCE',
            style: fonts.centuryGothic.style(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      ),
      pw.SizedBox(height: 24),
      pw.Text(
        'This is to certify that $recipient of $office, has appeared at $campus on $appearanceDate.',
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 20),
      pw.Text('Purpose of appearance:',
          style: fonts.centuryGothic.style(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      pw.SizedBox(height: 6),
      pw.Text(purpose, style: bodyStyle, textAlign: pw.TextAlign.justify),
      pw.SizedBox(height: 24),
      pw.Text(
        'This certificate is issued upon request for whatever legal or official purpose it may serve.',
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 20),
      pw.Text(
        'Issued this $day day of $monthYear, at $campus.',
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 50),
      pw.Center(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(coordinator,
                style: fonts.centuryGothic.style(
                    fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.Text(coordinatorTitle,
                style: fonts.centuryGothic.style(fontSize: 11, color: PdfColors.black)),
            pw.Text('Cagayan State University',
                style: fonts.centuryGothic.style(fontSize: 11, color: PdfColors.black)),
          ],
        ),
      ),
    ];
  }

  pw.Widget _buildPdfTable(List<dynamic> table, [List<dynamic>? tableColumns]) {
    // Use explicit column order if available; fall back to map keys
    final headers = (tableColumns != null && tableColumns.isNotEmpty)
        ? tableColumns.map((k) => k.toString()).toList()
        : (table.first as Map<dynamic, dynamic>?)?.keys.map((k) => k.toString()).toList() ?? [];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        for (var i = 0; i < headers.length; i++)
          i: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(h,
                    style: const pw.TextStyle(fontSize: 12),
                    textAlign: pw.TextAlign.center),
              ),
          ],
        ),
        ...table.map((row) {
          final m = row as Map<dynamic, dynamic>? ?? {};
          return pw.TableRow(
            children: [
              for (final h in headers)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(m[h]?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 12),
                      textAlign: pw.TextAlign.center),
                ),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _printPdf() async {
    try {
      final format = _paperSizes[_selectedPageSize] ?? PdfPageFormat.a4;
      await Printing.layoutPdf(
        format: format,
        onLayout: (format) async => _buildPdfBytes(format: format),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final format = _paperSizes[_selectedPageSize] ?? PdfPageFormat.a4;
      final pdfBytes = await _buildPdfBytes(format: format);
      final safeName = widget.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: '$safeName.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (outputPath == null) return;
      final file = File(outputPath);
      await file.writeAsBytes(pdfBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: $outputPath')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPng() async {
    setState(() => _exporting = true);
    try {
      final pngBytes = await _captureImage(pixelRatio: 3.0);
      final safeName = widget.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Image',
        fileName: '$safeName.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (outputPath == null) return;
      final file = File(outputPath);
      await file.writeAsBytes(pngBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: $outputPath')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showError(dynamic e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: DropdownButton<String>(
              value: _selectedPageSize,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.format_size, size: 20),
              items: _paperSizes.keys.map((size) {
                final fmt = _paperSizes[size]!;
                return DropdownMenuItem(
                  value: size,
                  child: Text(
                    '$size (${(fmt.width / PdfPageFormat.inch).toStringAsFixed(1)}" × ${(fmt.height / PdfPageFormat.inch).toStringAsFixed(1)}")',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPageSize = value);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print (PDF)',
            onPressed: _loading || _record == null || _exporting ? null : _printPdf,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Export',
            enabled: !_loading && _record != null && !_exporting,
            onSelected: (value) {
              switch (value) {
                case 'pdf':
                  _exportPdf();
                  break;
                case 'png':
                  _exportPng();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, size: 20),
                  title: Text('Export as PDF'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'png',
                child: ListTile(
                  leading: Icon(Icons.image, size: 20),
                  title: Text('Export as Image (PNG)'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _record == null
                  ? const EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Document not found',
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      child: Center(
                        child: ExcludeSemantics(
                          child: RepaintBoundary(
                            key: _previewKey,
                            child: _DocumentPreview(
                              record: _record!,
                              pageFormat: _paperSizes[_selectedPageSize] ?? PdfPageFormat.a4,
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  final Map<String, dynamic> record;
  final PdfPageFormat pageFormat;

  const _DocumentPreview({required this.record, required this.pageFormat});

  @override
  Widget build(BuildContext context) {
    final payload = (record['payload'] as Map<String, dynamic>?) ?? {};
    final type = record['document_type'] as Map<String, dynamic>?;
    final slug = type?['slug']?.toString() ?? '';
    final code = record['code']?.toString() ?? '';

    // Convert PDF points to screen pixels (1 pt = 1.333px at 96dpi)
    final widthPx = pageFormat.width * 1.333;
    final leftMarginPx = 0.5 * PdfPageFormat.inch * 1.333;
    final rightMarginPx = 0.5 * PdfPageFormat.inch * 1.333;
    final topMarginPx = 0.5 * PdfPageFormat.inch * 1.333;
    final bottomMarginPx = 1.5 * PdfPageFormat.inch * 1.333;
    // Sidebar scales proportionally with page width (119.4px is ~20% of A4 width 595px)
    final sidebarWidthPx = widthPx * 0.20;
    // Logo height scales with page size (58px for A4 width 595px)
    final logoHeight = 58.0 * (widthPx / 793.3); // 793.3 = A4 width in px
    // Content left start = sidebar + left margin
    final contentLeftPx = sidebarWidthPx + leftMarginPx;
    // 1.5 inch in px for sidebar bottom spacing
    final sidebarBottomSpacing = 1.5 * PdfPageFormat.inch * 1.333;

    return Container(
      width: widthPx,
      color: Colors.white,
      child: Stack(
        children: [
          // Sidebar fills the entire left side, full height
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: sidebarWidthPx,
            child: _buildSidebar(sidebarWidthPx, sidebarBottomSpacing),
          ),
          // Bottom art at bottom-right corner
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildBottomArt(sidebarWidthPx),
          ),
          // Footer aligned with logo position (left = contentLeftPx)
          Positioned(
            left: contentLeftPx,
            bottom: bottomMarginPx * 0.3,
            right: rightMarginPx,
            child: _buildFooter(),
          ),
          // Main content area
          Padding(
            padding: EdgeInsets.fromLTRB(
              contentLeftPx,
              topMarginPx,
              rightMarginPx,
              bottomMarginPx,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(logoHeight, leftMarginPx),
                const SizedBox(height: 6),
                const Divider(color: Color(0xFF808080), thickness: 0.8),
                const SizedBox(height: 14),
                slug == 'certificate-of-appearance'
                    ? _CertificateContent(
                        payload: payload,
                        code: code,
                      )
                    : _LetterContent(
                        payload: payload,
                        code: code,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double logoHeight, double logoSpacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/csu_logo.png',
                height: logoHeight,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.school,
                    size: logoHeight,
                    color: const Color(0xFF2E7D32),
                  );
                },
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Republic of the Philippines',
                    style: TextStyle(
                      fontFamily: 'CenturyGothic',
                      fontSize: 9,
                      color: Color(0xFF404040),
                    ),
                  ),
                  Text(
                    'CAGAYAN STATE UNIVERSITY',
                    style: TextStyle(
                      fontFamily: 'CenturyGothic',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF262626),
                    ),
                  ),
                  Text(
                    'CARIG CAMPUS',
                    style: TextStyle(
                      fontFamily: 'CenturyGothic',
                      fontSize: 11,
                      color: Color(0xFF404040),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Carig Sur, Tuguegarao City, Cagayan',
                    style: TextStyle(
                      fontFamily: 'CenturyGothic',
                      fontSize: 8.5,
                      color: Color(0xFF404040),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Campus TVET Office',
            style: TextStyle(
              fontFamily: 'Brush Script MT',
              fontSize: 17,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              color: Color(0xFF595959),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomArt(double scale) {
    final w = 170 * (scale / 119.4);
    final h = 90 * (scale / 119.4);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned(
            right: 8 * (scale / 119.4),
            bottom: 6 * (scale / 119.4),
            child: Image.asset(
              'assets/csu_building.png',
              width: 118 * (scale / 119.4),
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
          Positioned(
            right: 4 * (scale / 119.4),
            bottom: 40 * (scale / 119.4),
            child: Transform.rotate(
              angle: -0.35,
              child: Image.asset(
                'assets/csu_eagle.png',
                width: 34 * (scale / 119.4),
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(double widthPx, double bottomSpacing) {
    final scale = widthPx / 119.4;
    final body = TextStyle(
      fontFamily: 'Monotype Corsiva',
      fontSize: 8.5 * scale,
      color: Colors.black,
      height: 1.3,
      fontStyle: FontStyle.italic,
    );
    final heading = TextStyle(
      fontFamily: 'Monotype Corsiva',
      fontSize: 10 * scale,
      fontWeight: FontWeight.bold,
      color: Colors.black,
      height: 1.3,
      fontStyle: FontStyle.italic,
    );
    final group = TextStyle(
      fontFamily: 'Monotype Corsiva',
      fontSize: 9 * scale,
      fontWeight: FontWeight.bold,
      color: Colors.black,
      height: 1.3,
      fontStyle: FontStyle.italic,
    );

    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('- ', style: body),
              Expanded(child: Text(text, style: body)),
            ],
          ),
        );

    return SizedBox(
      width: widthPx,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/side_bar.png',
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12 * scale, 60 * scale, 26 * scale, bottomSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VISION', style: heading),
                const SizedBox(height: 2),
                Text(
                  'CSU is a University with global stature in the arts, culture, agriculture and fisheries, the sciences as well as technological and professional fields.',
                  style: body,
                ),
                const SizedBox(height: 8),
                Text('MISSION', style: heading),
                const SizedBox(height: 2),
                Text(
                  'Cagayan State University shall produce globally competent graduates through excellent instruction, innovative and creative research, responsive public service and productive industry and community engagement.',
                  style: body,
                ),
                const SizedBox(height: 8),
                Text('CORE VALUES', style: heading),
                const SizedBox(height: 2),
                Text('Competence', style: group),
                bullet('Critical Thinker'),
                bullet('Creative Problem -Solver'),
                bullet('Competitive Performer: Nationally, Regionally and Globally.'),
                const SizedBox(height: 6),
                Text('Social Responsibility', style: group),
                bullet('Sensitive to Ethical Demands'),
                bullet('Steward of the Environment for Future Generations'),
                bullet('Social Justice and Economic Equity Advocate.'),
                const SizedBox(height: 6),
                Text('Unifying Presence', style: group),
                bullet('Uniting Theory and Practice'),
                bullet('Uniting Strata of Society'),
                bullet('Unifying the Nation, the ASEAN Region and the world'),
                bullet('Uniting the University and the community.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    const base = TextStyle(
      fontFamily: 'Constantia',
      fontSize: 9,
      color: Colors.black,
    );
    const link = TextStyle(
      fontFamily: 'Constantia',
      fontSize: 9,
      color: Color(0xFF0462C1),
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFF0462C1),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: base,
              children: [
                TextSpan(text: 'Website: '),
                TextSpan(text: 'http://www.csucarig.edu.ph', style: link),
              ],
            ),
          ),
          RichText(
            text: const TextSpan(
              style: base,
              children: [
                TextSpan(text: 'Email Address: '),
                TextSpan(text: 'tvet@csucarig.edu.ph', style: link),
              ],
            ),
          ),
          const Text('Local No. 042', style: base),
        ],
      ),
    );
  }
}

class _CertificateContent extends StatelessWidget {
  final Map<String, dynamic> payload;
  final String code;

  const _CertificateContent({required this.payload, required this.code});

  @override
  Widget build(BuildContext context) {
    final recipient = payload['recipient_name']?.toString() ?? '';
    final office = payload['recipient_office']?.toString() ?? '';
    final campus = payload['campus_name']?.toString() ?? '';
    final appearanceDate = payload['appearance_date']?.toString() ?? '';
    final purpose = payload['purpose']?.toString() ?? '';
    final day = payload['issued_day']?.toString() ?? '';
    final monthYear = payload['issued_month_year']?.toString() ?? '';
    final coordinator = payload['coordinatorName']?.toString() ??
        payload['coordinator_name']?.toString() ??
        '';
    final coordinatorTitle = payload['coordinatorTitle']?.toString() ?? 'TVET Coordinator';

    const bodyStyle = TextStyle(
      fontFamily: 'CenturyGothic',
      fontSize: 12,
      color: Colors.black,
      height: 1.6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              code,
              style: const TextStyle(
                fontFamily: 'CenturyGothic',
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'CERTIFICATE OF APPEARANCE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'CenturyGothic',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text.rich(
          textAlign: TextAlign.justify,
          TextSpan(
            style: bodyStyle,
            children: [
              const TextSpan(text: 'This is to certify that '),
              TextSpan(
                text: recipient,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
              const TextSpan(text: ' of '),
              TextSpan(
                text: office,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
              const TextSpan(text: ', has appeared at '),
              TextSpan(
                text: campus,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
              const TextSpan(text: ' on '),
              TextSpan(
                text: appearanceDate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Purpose of appearance:',
          textAlign: TextAlign.justify,
          style: TextStyle(
            fontFamily: 'CenturyGothic',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 24),
          alignment: Alignment.bottomLeft,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black)),
          ),
          child: Text(
            purpose,
            textAlign: TextAlign.justify,
            softWrap: true,
            style: bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'This certificate is issued upon request for whatever legal or official purpose it may serve.',
          textAlign: TextAlign.justify,
          style: bodyStyle,
        ),
        const SizedBox(height: 20),
        Text.rich(
          textAlign: TextAlign.justify,
          TextSpan(
            style: bodyStyle,
            children: [
              const TextSpan(text: 'Issued this '),
              TextSpan(
                text: day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
              const TextSpan(text: ' day of '),
              TextSpan(
                text: monthYear,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
              const TextSpan(text: ', at '),
              TextSpan(
                text: campus,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 4.0),
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 300, maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                Text(
                  coordinator,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: 'CenturyGothic',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.black,
                  ),
                ),
                Text(
                  coordinatorTitle,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: 'CenturyGothic',
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  'Cagayan State University',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: 'CenturyGothic',
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LetterContent extends StatelessWidget {
  final Map<String, dynamic> payload;
  final String code;

  const _LetterContent({required this.payload, required this.code});

  @override
  Widget build(BuildContext context) {
    final date = payload['date']?.toString() ??
        payload['issued_at']?.toString() ??
        '';
    final to = payload['to']?.toString() ??
        payload['recipient']?.toString() ??
        '';
    final toDetail = payload['organization']?.toString() ??
        payload['recipient_office']?.toString() ??
        '';
    final address = payload['address']?.toString() ??
        payload['recipient_address']?.toString() ??
        '';
    final from = payload['from']?.toString() ??
        payload['campus_name']?.toString() ??
        '';
    final subject = payload['subject']?.toString() ?? '';
    final body = payload['body']?.toString() ?? '';
    final table = payload['table'] as List<dynamic>?;
    final tableColumns = payload['tableColumns'] as List<dynamic>?;
    final image = payload['image']?.toString() ??
        payload['image_url']?.toString() ??
        '';
    final coordinator = payload['coordinatorName']?.toString() ??
        payload['coordinator_name']?.toString() ??
        '';
    final coordinatorTitle = payload['coordinatorTitle']?.toString() ?? 'Campus TVET Coordinator';
    final greetings = payload['greetings']?.toString() ?? 'Sir:';
    final footerBody = payload['footerBody']?.toString() ?? '';

    const bodyStyle = TextStyle(
      fontFamily: 'CenturyGothic',
      fontSize: 12,
      color: Colors.black,
      height: 1.6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              code,
              style: const TextStyle(
                fontFamily: 'CenturyGothic',
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (date.isNotEmpty)
          Text(date, textAlign: TextAlign.left, style: bodyStyle),
        const SizedBox(height: 20),
        if (to.isNotEmpty)
          Text(to,
              textAlign: TextAlign.start,
              style: bodyStyle.copyWith(fontWeight: FontWeight.bold)),
        if (toDetail.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(toDetail, textAlign: TextAlign.start, style: bodyStyle),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(address, textAlign: TextAlign.start, style: bodyStyle),
        ],
        if (from.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Thru: $from',
              textAlign: TextAlign.start,
              style: bodyStyle.copyWith(fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 20),
        if (subject.isNotEmpty)
          Text(
            'Subject: $subject',
            textAlign: TextAlign.justify,
            style: bodyStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 16),
        Text(greetings, textAlign: TextAlign.justify, style: bodyStyle),
        const SizedBox(height: 4),
        const Text(
          'Greetings!',
          textAlign: TextAlign.justify,
          style: TextStyle(
            fontFamily: 'CenturyGothic',
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.justify,
          style: bodyStyle,
        ),
        if (table != null && table.isNotEmpty) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              // Use explicit column order if available; fall back to map keys
              final headers = (tableColumns != null && tableColumns.isNotEmpty)
                  ? tableColumns.map((k) => k.toString()).toList()
                  : (table.first as Map<dynamic, dynamic>?)?.keys.map((k) => k.toString()).toList() ?? [];
              return Table(
                border: TableBorder.all(
                  color: Colors.black,
                  width: 0.5,
                ),
                columnWidths: {
                  for (var i = 0; i < headers.length; i++)
                    i: const FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade200),
                    children: [
                      for (final h in headers)
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(h,
                              style: bodyStyle,
                              textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                  ...table.map<TableRow>((row) {
                    final m = row as Map<dynamic, dynamic>? ?? {};
                    return TableRow(
                      children: [
                        for (final h in headers)
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(m[h]?.toString() ?? '',
                                style: bodyStyle,
                                textAlign: TextAlign.center),
                          ),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ],
        if (image.isNotEmpty) ...[
          const SizedBox(height: 16),
          Image.network(
            image,
            height: 250,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ],
        if (footerBody.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            footerBody,
            textAlign: TextAlign.justify,
            style: bodyStyle,
          ),
        ],
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Very respectfully yours,',
                  textAlign: TextAlign.left, style: bodyStyle),
              const SizedBox(height: 5.67),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        coordinator,
                        textAlign: TextAlign.left,
                        style: bodyStyle.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        coordinatorTitle,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: 'CenturyGothic',
                          fontSize: 11,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
