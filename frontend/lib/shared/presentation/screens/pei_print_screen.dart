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

/// Print preview for TESDA "Performance Evaluation Instrument" (PEI).
/// Exact pixel-perfect replica of TESDA-OP-CO-04-F29 and F30.
/// A4: 595.3 x 841.9 pt (8.27 x 11.69 in)
class PeiPrintScreen extends StatefulWidget {
  final String code;
  const PeiPrintScreen({super.key, required this.code});
  @override
  State<PeiPrintScreen> createState() => _PeiPrintScreenState();
}

class _PeiPrintScreenState extends State<PeiPrintScreen> {
  final _previewKey1 = GlobalKey();
  final _previewKey2 = GlobalKey();
  Map<String, dynamic>? _record;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/documents/${widget.code}');
      if (!mounted) return;
      setState(() { _record = res.data as Map<String, dynamic>; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _p(String key) {
    final payload = (_record?['payload'] as Map<String, dynamic>?) ?? {};
    return payload[key]?.toString() ?? '';
  }

  Future<Uint8List> _captureImage(GlobalKey key, {double pixelRatio = 3.0}) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Unable to capture preview');
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Unable to encode image');
    return byteData.buffer.asUint8List();
  }

  Future<Uint8List> _buildPdfBytes(PdfPageFormat pageFormat) async {
    final bytes1 = await _captureImage(_previewKey1, pixelRatio: 4.0);
    final bytes2 = await _captureImage(_previewKey2, pixelRatio: 4.0);
    final pdf = pw.Document();
    pw.Widget pageImage(Uint8List bytes) => pw.SizedBox(
          width: pageFormat.width,
          height: pageFormat.height,
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
        );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pageImage(bytes1),
      ),
    );
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pageImage(bytes2),
      ),
    );
    return pdf.save();
  }

  Future<void> _printPdf() async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _buildPdfBytes(format),
      );
    }
    catch (e) { _showError(e); }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final pdfBytes = await _buildPdfBytes(PdfPageFormat.a4);
      final safeName = widget.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF', fileName: '$safeName.pdf',
        type: FileType.custom, allowedExtensions: ['pdf'],
      );
      if (outputPath == null) return;
      await File(outputPath).writeAsBytes(pdfBytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $outputPath')));
    } catch (e) { _showError(e); }
    finally { if (mounted) setState(() => _exporting = false); }
  }

  void _showError(dynamic e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }

  // === EXACT dimensions from original .docx (in points) ===
  // A4: 595.3 x 841.9 pt
  // Margins: top=63, bottom=72
  // Table width: 462.45pt — centered, horizontal padding = (595.3 - 463.35) / 2 = 65.975pt
  static const double _pageW = 595.3;
  static const double _pageH = 841.9;
  static const double _marginH = 65.975;
  static const double _marginTop = 63.0;
  static const double _marginBottom = 72.0;

  // Main table: 462.45pt, 13 grid columns
  static const double _mainW = 462.45;
  // Grid cols (pt): 92.6, 24.25, 107.65, 21.5, 19.5, 32.4, 45.05, 8.05, 15.75, 23.9, 23.9, 23.9, 24
  // Effective span widths for F29:
  static const double _labelW = 116.85;    // span 2 (92.6+24.25)
  static const double _valueW = 345.6;     // span 11
  static const double _respValW = 148.65;  // span 3 (107.65+21.5+19.5) — F29
  static const double _dateLblW = 85.5;    // span 3 (32.4+45.05+8.05) — F29
  static const double _dateValW = 111.45;  // span 5 (15.75+23.9+23.9+23.9+24) — F29
  // F30 has slightly different spans:
  static const double _respValW2 = 162.15; // span 3 — F30
  static const double _dateLblW2 = 81.0;   // span 3 — F30
  static const double _dateValW2 = 102.45; // span 5 — F30

  static const double _itemW = 342.95;     // span 7
  static const double _ratingW = 119.5;    // span 6
  static const double _rate5W = 23.8;      // span 2
  static const double _rateW = 23.9;       // single
  static const double _rate1W = 24.0;      // single
  // SCALE GUIDE row widths
  static const double _scaleLblW = 92.6;
  static const double _scale1W = 131.9;    // span 2
  static const double _scale2W = 73.4;     // span 3 (F29) / 73.4 (F30: 21.5+33+18.9=73.4)
  static const double _scale3W = 45.05;
  static const double _scale4W = 119.5;    // span 6
  // FINAL RATING / Signature
  static const double _finalLblW = 246.0;  // span 4
  static const double _finalValW = 216.45; // span 9

  // FOR TESDA table: 463.35pt, 4 cols
  static const double _tesdaW = 463.35;
  static const double _t0 = 11.8;
  static const double _t1 = 120.3;
  static const double _t2 = 114.8;
  static const double _t3 = 216.45;

  // Border: sz=4 = 0.5pt for main table
  static const double _bw = 0.5;
  static const Color _black = Color(0xFF000000);
  static const Color _headerBg = Color(0xFFD9D9D9);

  // Fonts: Arial 12pt labels, 10pt values, 12pt headers/footnotes
  static const TextStyle _f10 = TextStyle(fontFamily: 'Arial', fontSize: 10, color: _black, height: 1.0);
  static const TextStyle _f10b = TextStyle(fontFamily: 'Arial', fontSize: 10, color: _black, fontWeight: FontWeight.bold, height: 1.0);
  static const TextStyle _f12 = TextStyle(fontFamily: 'Arial', fontSize: 12, color: _black, height: 1.0);
  static const TextStyle _f12b = TextStyle(fontFamily: 'Arial', fontSize: 12, color: _black, fontWeight: FontWeight.bold, height: 1.0);
  static const TextStyle _f10bCheck = TextStyle(
    fontFamily: 'Arial',
    fontFamilyFallback: ['Checkmark'],
    fontSize: 10,
    color: _black,
    fontWeight: FontWeight.bold,
    height: 1.0,
  );

  // F29 items (by Candidate) — 7 items
  static const List<String> _f29Items = [
    '1. Physical appearance and composure\n(Pangkalahatang anyong pisikal at kung paano magdala sa sarili)',
    '2. Provided clear and concise instruction that is easily understood by the candidates\n(Nagbigay ng malinaw at maigsi na instruction na madaling maintindihan ng mga candidates.)',
    '3. Established good rapport and communication with candidates\n(Nagpakita ng magandang kaugnayan at maayos na pakikipag-usap sa mga candidates)',
    '4. Provided clear answers to queries and/or comments from the candidates\n(Nagbigay ng malinaw na mga sagot sa mga katanungan at komento mula sa mga candidates)',
    '5. Exhibited respectable behavior\n(Nagpakita ng kagalang-galang na pag-uugali)',
    '6. Explained the purpose and scope (context) of assessment\n(Ipinaliwanag ang layunin at saklaw (konteksto) ng assessment.)',
    '7. Provides fair, reliable and valid assessment decision\n(Kakayahang magbigay ng pantay, ugma at tamang desisyon sa resulta ng pagsusulit)',
  ];

  // F29 row heights (pt)
  static const List<double> _f29Heights = [
    21.55, // R0: Assessor's Name
    21.7,  // R1: Qualification
    26.35, // R2: Name of Respondent | Date
    22.05, // R3: INSTRUCTIONS
    30.95, // R4: SCALE GUIDE
    20.5,  // R5: ITEM | RATING
    15.2,  // R6: empty | 5 4 3 2 1
    24.05, // R7: Item 1
    35.6,  // R8: Item 2
    35.7,  // R9: Item 3
    35.6,  // R10: Item 4
    24.05, // R11: Item 5
    25.15, // R12: Item 6
    35.6,  // R13: Item 7
    20.35, // R14: Sub-score
    20.35, // R15: FINAL RATING
    20.5,  // R16: Signature of Respondent
  ];

  // F30 items (by AC Manager) — 5 items
  static const List<String> _f30Items = [
    '1. Planned and prepared the evidence gathering process\n(Nagplano at naghanda ng proseso ng pangangalap ng ebidensya para sa assessment)',
    '2. Provided allowable/reasonable adjustments in the assessment procedure\n(Nagbigay ng mga konsiderasyon/makatwirang pagsasaayos sa pamamaraan ng assessment)',
    '3. Collected appropriate evidence during the conduct of assessment\n(Nangalap at sumuri ng mga tamang ebidensya habang nagbibigay ng assessment)',
    '4. Provided clear and constructive feedback on the assessment decision\n(Nagbigay ng malinaw at tamang kaukulang opinyon sa resulta ng assessment)',
    '5. Provided fair, reliable and valid assessment decision\n(Kakayahang magbigay ng pantay, ugma at tamang desisyon sa resulta ng pagsusulit)',
  ];

  // F30 row heights (pt)
  static const List<double> _f30Heights = [
    21.55, // R0
    21.7,  // R1
    26.35, // R2
    22.05, // R3
    30.95, // R4
    20.5,  // R5
    15.2,  // R6
    35.6,  // R7: Item 1
    48.35, // R8: Item 2
    40.0,  // R9: Item 3
    49.45, // R10: Item 4
    35.6,  // R11: Item 5
    20.35, // R12: Sub-score
    20.35, // R13: FINAL RATING
    20.5,  // R14: Signature
  ];

  // FOR TESDA table row heights
  static const List<double> _tesdaHeights = [24.55, 38.7, 15.65, 27.6];

  /// Build a cell with proper borders (no doubling).
  Widget _cell({
    required double width,
    required double height,
    Widget? child,
    Color bg = Colors.transparent,
    bool isLastInRow = false,
    bool isLastRow = false,
    double borderWidth = _bw,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: _black, width: borderWidth),
          left: BorderSide(color: _black, width: borderWidth),
          right: isLastInRow ? BorderSide(color: _black, width: borderWidth) : BorderSide.none,
          bottom: isLastRow ? BorderSide(color: _black, width: borderWidth) : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(3, 1, 2, 1),
      child: child,
    );
  }

  Widget _txt(String text, {TextStyle style = _f10, Alignment align = Alignment.centerLeft}) =>
      Align(alignment: align, child: Text(text, style: style));

  Widget _empty(double w, double h, {bool last = false, bool isLastRow = false}) =>
      _cell(width: w, height: h, isLastInRow: last, isLastRow: isLastRow);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),
        actions: [
          if (_exporting)
            const Padding(padding: EdgeInsets.all(14), child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            IconButton(icon: const Icon(Icons.print), tooltip: 'Print (PDF)', onPressed: _loading || _record == null ? null : _printPdf),
            IconButton(icon: const Icon(Icons.download), tooltip: 'Export PDF', onPressed: _loading || _record == null ? null : _exportPdf),
          ],
        ],
      ),
      body: _loading ? const LoadingState()
        : _error != null ? ErrorState(message: _error!, onRetry: _load)
        : _record == null ? const EmptyState(icon: Icons.description_outlined, title: 'Document not found')
        : SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Center(child: Column(children: [
              // Page 1: F29 (Candidate)
              ExcludeSemantics(child: RepaintBoundary(key: _previewKey1, child: _buildPage1())),
              const SizedBox(height: 32),
              // Page 2: F30 (AC Manager)
              ExcludeSemantics(child: RepaintBoundary(key: _previewKey2, child: _buildPage2())),
            ])),
          ),
    );
  }

  Widget _buildPage1() {
    return Container(
      width: _pageW,
      height: _pageH,
      color: Colors.white,
      padding: const EdgeInsets.only(top: _marginTop, left: _marginH, right: _marginH, bottom: _marginBottom),
      child: _buildForm(
        formCode: 'TESDA-OP-CO-04-F29',
        revNo: 'Rev. No.00-05/04/23',
        subtitle: '(To be accomplished by Candidates)',
        items: _f29Items,
        rowHeights: _f29Heights,
        respValW: _respValW,
        dateLblW: _dateLblW,
        dateValW: _dateValW,
        respondentName: _p('respondentName1'),
        dateAccomplished: _p('dateAccomplished1'),
        finalRating: _p('finalRating1'),
        evaluatorRemarks: _p('evaluatorRemarks1'),
        footnote: '*Shall be accomplished by two (2) candidates per assessment schedule. The candidates shall be 1 Competent and 1 Not Yet Competent',
      ),
    );
  }

  Widget _buildPage2() {
    return Container(
      width: _pageW,
      height: _pageH,
      color: Colors.white,
      padding: const EdgeInsets.only(top: _marginTop, left: _marginH, right: _marginH, bottom: _marginBottom),
      child: _buildForm(
        formCode: 'TESDA-OP-CO-04-F30',
        revNo: 'Rev. No. 00-05/04/23',
        subtitle: '(To be accomplished by the AC Manager)',
        items: _f30Items,
        rowHeights: _f30Heights,
        respValW: _respValW2,
        dateLblW: _dateLblW2,
        dateValW: _dateValW2,
        respondentName: _p('respondentName2'),
        dateAccomplished: _p('dateAccomplished2'),
        finalRating: _p('finalRating2'),
        evaluatorRemarks: _p('evaluatorRemarks2'),
        footnote: '*Shall be accomplished by the AC Manager per assessment schedule.',
      ),
    );
  }

  Widget _buildForm({
    required String formCode,
    required String revNo,
    required String subtitle,
    required List<String> items,
    required List<double> rowHeights,
    required double respValW,
    required double dateLblW,
    required double dateValW,
    required String respondentName,
    required String dateAccomplished,
    required String finalRating,
    required String evaluatorRemarks,
    required String footnote,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header: form code (right, 12pt bold), rev (right, 12pt)
      Align(alignment: Alignment.centerRight, child: Text(formCode, style: _f12b)),
      Align(alignment: Alignment.centerRight, child: Text(revNo, style: _f12)),
      const SizedBox(height: 8),
      // Title (center, 12pt)
      const Center(child: Text('PERFORMANCE EVALUATION INSTRUMENT', style: _f12)),
      const SizedBox(height: 2),
      // Subtitle (center, 12pt)
      Center(child: Text(subtitle, style: _f12)),
      const SizedBox(height: 8),
      // Main table
      Center(child: _buildMainTable(items, rowHeights, respValW, dateLblW, dateValW, respondentName, dateAccomplished, finalRating)),
      const SizedBox(height: 8),
      // FOR TESDA USE ONLY table
      Center(child: _buildTesdaTable(evaluatorRemarks)),
      const SizedBox(height: 6),
      // Footnote (12pt)
      Text(footnote, style: _f12),
    ]);
  }

  Widget _buildMainTable(
    List<String> items, List<double> heights,
    double respValW, double dateLblW, double dateValW,
    String respondentName, String dateAccomplished, String finalRating,
  ) {
    final rows = <Widget>[];
    final itemCount = items.length;
    // Total rows: 7 header rows + itemCount + 3 footer rows = 10 + itemCount
    final totalRows = 7 + itemCount + 3;
    final lastIdx = totalRows - 1;
    int ri = 0;

    // R0: Assessor's Name | value
    rows.add(Row(children: [
      _cell(width: _labelW, height: heights[0], bg: _headerBg, child: _txt("Assessor\u2019s Name", style: _f12), isLastRow: ri == lastIdx),
      _cell(width: _valueW, height: heights[0], child: _txt(' ${_p('assessorName')}', style: _f10), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // R1: Qualification | value
    rows.add(Row(children: [
      _cell(width: _labelW, height: heights[1], bg: _headerBg, child: _txt('Qualification', style: _f12), isLastRow: ri == lastIdx),
      _cell(width: _valueW, height: heights[1], child: _txt(' ${_p('qualification')}', style: _f10), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // R2: Name of Respondent | value | Date Accomplished | value
    rows.add(Row(children: [
      _cell(width: _labelW, height: heights[2], bg: _headerBg, child: _txt('Name of Respondent', style: _f10), isLastRow: ri == lastIdx),
      _cell(width: respValW, height: heights[2], child: _txt(' $respondentName', style: _f10), isLastRow: ri == lastIdx),
      _cell(width: dateLblW, height: heights[2], bg: _headerBg, child: _txt('Date Accomplished', style: _f10), isLastRow: ri == lastIdx),
      _cell(width: dateValW, height: heights[2], child: _txt(' $dateAccomplished', style: _f10), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // R3: INSTRUCTIONS (full span)
    rows.add(Row(children: [
      _cell(width: _mainW, height: heights[3], child: _txt('INSTRUCTIONS: Put a tick (\u2713) mark in the appropriate column', style: _f10bCheck), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // R4: SCALE GUIDE (no borders in original) — two stacked lines per cell
    Widget scaleLines(String l1, String l2) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text(l1, style: _f10), Text(l2, style: _f10)],
        );
    rows.add(Row(children: [
      _cell(width: _scaleLblW, height: heights[4], child: _txt('SCALE GUIDE', style: _f10), isLastRow: ri == lastIdx),
      _cell(width: _scale1W, height: heights[4], child: scaleLines('5\u2013 Very Satisfactory', '4 \u2013 Satisfactory'), isLastRow: ri == lastIdx),
      _cell(width: _scale2W, height: heights[4], child: scaleLines('3 \u2013 Good', '2 \u2013 Fair'), isLastRow: ri == lastIdx),
      _cell(width: _scale3W, height: heights[4], isLastRow: ri == lastIdx),
      _cell(width: _scale4W, height: heights[4], child: _txt('1 \u2013 Poor', style: _f10), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // R5: ITEM | RATING
    rows.add(Row(children: [
      _cell(width: _itemW, height: heights[5], bg: _headerBg, child: _txt('ITEM', style: _f12b, align: Alignment.center), isLastRow: ri == lastIdx),
      _cell(width: _ratingW, height: heights[5], bg: _headerBg, child: _txt('RATING', style: _f12b, align: Alignment.center), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // R6: empty | 5 | 4 | 3 | 2 | 1
    rows.add(Row(children: [
      _cell(width: _itemW, height: heights[6], isLastRow: ri == lastIdx),
      _cell(width: _rate5W, height: heights[6], child: _txt('5', style: _f12, align: Alignment.center), isLastRow: ri == lastIdx),
      _cell(width: _rateW, height: heights[6], child: _txt('4', style: _f12, align: Alignment.center), isLastRow: ri == lastIdx),
      _cell(width: _rateW, height: heights[6], child: _txt('3', style: _f12, align: Alignment.center), isLastRow: ri == lastIdx),
      _cell(width: _rateW, height: heights[6], child: _txt('2', style: _f12, align: Alignment.center), isLastRow: ri == lastIdx),
      _cell(width: _rate1W, height: heights[6], child: _txt('1', style: _f12, align: Alignment.center), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // Item rows
    for (int i = 0; i < itemCount; i++) {
      final h = heights[7 + i];
      rows.add(Row(children: [
        _cell(width: _itemW, height: h, child: _txt(items[i], style: _f10), isLastRow: ri == lastIdx),
        _empty(_rate5W, h, isLastRow: ri == lastIdx),
        _empty(_rateW, h, isLastRow: ri == lastIdx),
        _empty(_rateW, h, isLastRow: ri == lastIdx),
        _empty(_rateW, h, isLastRow: ri == lastIdx),
        _empty(_rate1W, h, last: true, isLastRow: ri == lastIdx),
      ]));
      ri++;
    }

    // Sub - score
    final subScoreIdx = 7 + itemCount;
    rows.add(Row(children: [
      _cell(width: _itemW, height: heights[subScoreIdx], bg: _headerBg, child: _txt('Sub - score', style: _f10, align: Alignment.center), isLastRow: ri == lastIdx),
      _empty(_rate5W, heights[subScoreIdx], isLastRow: ri == lastIdx),
      _empty(_rateW, heights[subScoreIdx], isLastRow: ri == lastIdx),
      _empty(_rateW, heights[subScoreIdx], isLastRow: ri == lastIdx),
      _empty(_rateW, heights[subScoreIdx], isLastRow: ri == lastIdx),
      _empty(_rate1W, heights[subScoreIdx], last: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // FINAL RATING
    final finalIdx = 7 + itemCount + 1;
    rows.add(Row(children: [
      _cell(width: _finalLblW, height: heights[finalIdx], bg: _headerBg, child: _txt('FINAL RATING', style: _f10b, align: Alignment.centerLeft), isLastRow: ri == lastIdx),
      _cell(width: _finalValW, height: heights[finalIdx], child: _txt(finalRating, style: _f10b, align: Alignment.center), isLastInRow: true, isLastRow: ri == lastIdx),
    ]));
    ri++;

    // Signature of Respondent
    final sigIdx = 7 + itemCount + 2;
    rows.add(Row(children: [
      _cell(width: _finalLblW, height: heights[sigIdx], bg: _headerBg, child: _txt('Signature of Respondent', style: _f10b), isLastRow: ri == lastIdx),
      _cell(width: _finalValW, height: heights[sigIdx], isLastInRow: true, isLastRow: ri == lastIdx),
    ]));

    return SizedBox(width: _mainW, child: Column(children: rows));
  }

  /// Custom cell for TESDA table with explicit per-side border control.
  Widget _tesdaCell({
    required double width,
    required double height,
    Widget? child,
    Color bg = Colors.transparent,
    bool top = false,
    bool left = false,
    bool right = false,
    bool bottom = false,
    double bottomWidth = _bw,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: top ? const BorderSide(color: _black, width: _bw) : BorderSide.none,
          left: left ? const BorderSide(color: _black, width: _bw) : BorderSide.none,
          right: right ? const BorderSide(color: _black, width: _bw) : BorderSide.none,
          bottom: bottom ? BorderSide(color: _black, width: bottomWidth) : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(3, 1, 2, 1),
      child: child,
    );
  }

  Widget _buildTesdaTable(String evaluatorRemarks) {
    const thick = 1.0; // sz8 = 1pt

    // R0: small cell (no right) | FOR TESDA USE ONLY (no left, thick bottom)
    final r0 = Row(children: [
      _tesdaCell(width: _t0, height: _tesdaHeights[0],
        top: true, left: true, bottom: true, bottomWidth: thick),
      _tesdaCell(width: _t1 + _t2 + _t3, height: _tesdaHeights[0], bg: _headerBg,
        child: _txt('FOR TESDA USE ONLY', style: _f10b, align: Alignment.center),
        top: true, right: true, bottom: true, bottomWidth: thick),
    ]);

    // R1: EVALUATOR'S REMARKS (full span, thick top, 2mm left padding)
    final r1 = Row(children: [
      _tesdaCell(width: _tesdaW, height: _tesdaHeights[1],
        child: Padding(
          padding: const EdgeInsets.only(left: 5.67), // 2mm
          child: Align(
            alignment: Alignment.topLeft,
            child: Text('EVALUATOR\u2019S REMARKS:', style: _f10),
          ),
        ),
        top: true, left: true, right: true, bottom: true, bottomWidth: thick),
    ]);

    // R2: [empty] | RECOMMENDATION: | [empty] | [empty] — no internal verticals, no bottom
    final r2 = Row(children: [
      _tesdaCell(width: _t0, height: _tesdaHeights[2],
        top: true, left: true),
      _tesdaCell(width: _t1, height: _tesdaHeights[2],
        child: _txt('RECOMMENDATION:', style: _f10),
        top: true),
      _tesdaCell(width: _t2, height: _tesdaHeights[2],
        top: true),
      _tesdaCell(width: _t3, height: _tesdaHeights[2],
        top: true, right: true),
    ]);

    // R3: small | For re-accreditation | YES / NO (stacked) | For further review
    // No top, no internal verticals
    Widget checkboxLabel(String label) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                border: Border.all(color: _black, width: 0.5),
              ),
            ),
            const SizedBox(width: 3),
            Text(label, style: _f10),
          ],
        );

    final r3 = Row(children: [
      _tesdaCell(width: _t0, height: _tesdaHeights[3],
        left: true, bottom: true),
      _tesdaCell(width: _t1, height: _tesdaHeights[3],
        child: _txt('For re-accreditation', style: _f10),
        bottom: true),
      _tesdaCell(width: _t2, height: _tesdaHeights[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            checkboxLabel('YES'),
            const SizedBox(height: 2),
            checkboxLabel('NO'),
          ],
        ),
        bottom: true),
      _tesdaCell(width: _t3, height: _tesdaHeights[3],
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: checkboxLabel('For further review'),
          ),
        ),
        right: true, bottom: true),
    ]);

    return SizedBox(width: _tesdaW, child: Column(children: [r0, r1, r2, r3]));
  }
}
