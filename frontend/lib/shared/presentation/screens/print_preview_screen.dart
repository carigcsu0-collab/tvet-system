// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';

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
    final bytes = await _captureImage();
    final pdf = pw.Document();
    final imageProvider = pw.MemoryImage(bytes);
    pdf.addPage(
      pw.Page(
        pageFormat: format ?? PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Image(
            imageProvider,
            fit: pw.BoxFit.contain,
          ),
        ),
      ),
    );
    return pdf.save();
  }

  Future<void> _printPdf() async {
    try {
      final pdfBytes = await _buildPdfBytes();
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final pdfBytes = await _buildPdfBytes();
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
                            child: _DocumentPreview(record: _record!),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  final Map<String, dynamic> record;

  const _DocumentPreview({required this.record});

  @override
  Widget build(BuildContext context) {
    final payload = (record['payload'] as Map<String, dynamic>?) ?? {};
    final type = record['document_type'] as Map<String, dynamic>?;
    final slug = type?['slug']?.toString() ?? '';
    final code = record['code']?.toString() ?? '';

    return Container(
      width: 595,
      height: 842,
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 119.4,
            child: _buildSidebar(),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildBottomArt(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(136, 28, 40, 24),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 6),
                const Divider(color: Color(0xFF808080), thickness: 0.8),
                const SizedBox(height: 14),
                Expanded(
                  child: slug == 'certificate-of-appearance'
                      ? _CertificateContent(
                          payload: payload,
                          code: code,
                        )
                      : _LetterContent(
                          payload: payload,
                          code: code,
                        ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/csu_logo.png',
              height: 58,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.school,
                  size: 58,
                  color: Color(0xFF2E7D32),
                );
              },
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
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
            ),
          ],
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

  Widget _buildBottomArt() {
    return SizedBox(
      width: 170,
      height: 90,
      child: Stack(
        children: [
          Positioned(
            right: 8,
            bottom: 6,
            child: Image.asset(
              'assets/csu_building.png',
              width: 118,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 40,
            child: Transform.rotate(
              angle: -0.35,
              child: Image.asset(
                'assets/csu_eagle.png',
                width: 34,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    const body = TextStyle(
      fontFamily: 'Monotype Corsiva',
      fontSize: 8.5,
      color: Colors.black,
      height: 1.3,
      fontStyle: FontStyle.italic,
    );
    const heading = TextStyle(
      fontFamily: 'Monotype Corsiva',
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.black,
      height: 1.3,
      fontStyle: FontStyle.italic,
    );
    const group = TextStyle(
      fontFamily: 'Monotype Corsiva',
      fontSize: 9,
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
              const Text('- ', style: body),
              Expanded(child: Text(text, style: body)),
            ],
          ),
        );

    return SizedBox(
      width: 119.4,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/side_bar.png',
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 60, 26, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VISION', style: heading),
                const SizedBox(height: 2),
                const Text(
                  'CSU is a University with global stature in the arts, culture, agriculture and fisheries, the sciences as well as technological and professional fields.',
                  style: body,
                ),
                const SizedBox(height: 8),
                const Text('MISSION', style: heading),
                const SizedBox(height: 2),
                const Text(
                  'Cagayan State University shall produce globally competent graduates through excellent instruction, innovative and creative research, responsive public service and productive industry and community engagement.',
                  style: body,
                ),
                const SizedBox(height: 8),
                const Text('CORE VALUES', style: heading),
                const SizedBox(height: 2),
                const Text('Competence', style: group),
                bullet('Critical Thinker'),
                bullet('Creative Problem -Solver'),
                bullet('Competitive Performer: Nationally, Regionally and Globally.'),
                const SizedBox(height: 6),
                const Text('Social Responsibility', style: group),
                bullet('Sensitive to Ethical Demands'),
                bullet('Steward of the Environment for Future Generations'),
                bullet('Social Justice and Economic Equity Advocate.'),
                const SizedBox(height: 6),
                const Text('Unifying Presence', style: group),
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
    final image = payload['image']?.toString() ??
        payload['image_url']?.toString() ??
        '';
    final coordinator = payload['coordinatorName']?.toString() ??
        payload['coordinator_name']?.toString() ??
        '';
    final coordinatorTitle = payload['coordinatorTitle']?.toString() ?? 'Campus TVET Coordinator';

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
        const Text('Sir:', textAlign: TextAlign.justify, style: bodyStyle),
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
              final first = table.first as Map<dynamic, dynamic>?;
              final headers =
                  first?.keys.map((k) => k.toString()).toList() ?? [];
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
        const Spacer(),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text('Very respectfully yours,',
                  textAlign: TextAlign.left, style: bodyStyle),
              const SizedBox(height: 48),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 50),
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
