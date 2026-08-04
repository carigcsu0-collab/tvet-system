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

/// Print preview for TESDA "Report on Assessment Proceedings" (RAP).
/// Exact pixel-perfect replica of TESDA-OP-CO-05-F34.
/// A4: 595.3 x 841.9 pt (8.27 x 11.69 in)
class RapPrintScreen extends StatefulWidget {
  final String code;
  const RapPrintScreen({super.key, required this.code});
  @override
  State<RapPrintScreen> createState() => _RapPrintScreenState();
}

class _RapPrintScreenState extends State<RapPrintScreen> {
  final _previewKey = GlobalKey();
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

  Future<Uint8List> _captureImage({double pixelRatio = 3.0}) async {
    final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Unable to capture preview');
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Unable to encode image');
    return byteData.buffer.asUint8List();
  }

  Future<Uint8List> _buildPdfBytes() async {
    final bytes = await _captureImage();
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
    ));
    return pdf.save();
  }

  Future<void> _printPdf() async {
    try { await Printing.layoutPdf(onLayout: (f) async => await _buildPdfBytes()); }
    catch (e) { _showError(e); }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final pdfBytes = await _buildPdfBytes();
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
  // Margins: top=21.3, left=72, right=72, bottom=72
  // Table width: 525.85pt — centered on page, extends into side margins
  // Horizontal padding = (595.3 - 525.85) / 2 = 34.725pt each side
  static const double _pageW = 595.3;
  static const double _marginH = 34.725;
  static const double _marginTop = 36.0; // 0.5 inch header margin
  static const double _marginBottom = 72.0;
  static const double _tableW = 525.85;
  // Grid columns (pt): 202.05, 90.45, 36.2, 10.1, 25.15, 96, 65.9
  // Effective span widths:
  static const double _cLabel = 202.05;      // col 0
  static const double _cValue = 323.8;       // col 1-6 (90.45+36.2+10.1+25.15+96+65.9)
  static const double _cDateVal = 136.75;    // col 1-3 (90.45+36.2+10.1)
  static const double _cNoLabel = 121.15;    // col 4-5 (25.15+96)
  static const double _cNoVal = 65.9;        // col 6
  static const double _cItems = 292.5;       // col 0-1 (202.05+90.45)
  static const double _cYes = 36.2;          // col 2
  static const double _cNo = 35.25;          // col 3-4 (10.1+25.15)
  static const double _cAreas = 161.9;       // col 5-6 (96+65.9)
  static const double _cPrepared = 292.5;    // col 0-1
  static const double _cDateLine = 233.35;   // col 2-6 (36.2+10.1+25.15+96+65.9)

  // Row heights (pt) from original
  static const List<double> _rowHeights = [
    28.8,  // Row 0: Center name
    16.05, // Row 1: Accreditation Number
    15.95, // Row 2: Title of Qualification
    19.1,  // Row 3: Date | No. of Candidates
    15.8,  // Row 4: Name of Competency Assessor
    14.8,  // Row 5: Findings and Observations
    23.0,  // Row 6: Column headers
    28.2,  // Row 7: Item 1
    28.1,  // Row 8: Item 2
    28.1,  // Row 9: Item 3
    28.1,  // Row 10: Item 4
    18.75, // Row 11: Item 5
    28.1,  // Row 12: Item 6
    28.1,  // Row 13: Item 7
    28.1,  // Row 14: Item 8
    28.1,  // Row 15: Item 9
    28.1,  // Row 16: Item 10
    28.1,  // Row 17: Item 11
    125.0, // Row 18: Item 12 (enlarged for main text + 6 bullets with 1mm spacing)
    36.92, // Row 19: Narrative (31.25 + 2mm=5.67pt spacing)
    57.72, // Row 20: Prepared by | Date (52.05 + 2mm=5.67pt spacing above)
  ];

  // Border: sz=3 = 3/8 pt = 0.375pt (matches RAP.docx)
  static const double _bw = 0.375;
  static const Color _black = Color(0xFF000000);
  static const Color _headerBg = Color(0xFFD9D9D9);

  // Cell margins: left=5.2pt, right=2.3pt, top=0.3pt
  static const EdgeInsets _cellPad = EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3);

  // Fonts: Arial 10pt default, 12pt title (matches PEI font/style)
  static const TextStyle _f10 = TextStyle(fontFamily: 'Arial', fontSize: 10, color: _black, height: 1.0);
  static const TextStyle _f10b = TextStyle(fontFamily: 'Arial', fontSize: 10, color: _black, fontWeight: FontWeight.bold, height: 1.0);
  static const TextStyle _f12b = TextStyle(fontFamily: 'Arial', fontSize: 12, color: _black, fontWeight: FontWeight.bold, height: 1.0);

    // 12 items from original — item 12 has bullet sub-items
    static const List<List<String>> _items = [
      ['1. Competency Assessor has a signed Letter of Appointment'],
      ['2. Attendance of the candidates is checked and Admission Slips are verified and collected'],
      ['3. Supplies and materials are available during the conduct of assessment'],
      ['4. Tools and equipment are available and in good working conditions'],
      ['5. Assessment starts on time'],
      ['6. Conduct of assessment is in accordance with the methods identified in the CATs'],
      ['7. Projects produced by the candidates are in accordance with the requirements in the CATs.'],
      ['8. Candidates are provided  with clear and constructive feedback on the assessment decision  (one-on-one)'],
      ['9. Assessor has the ability to manage the competency assessment proceedings'],
      ['10. Complaints of candidates  are properly addressed and handled by the Assessor  & the AC, when applicable'],
      ['11. Assessment Packages issued to the Assessor are  completely returned upon completion of assessment'],
      [
        '12. Assessment-related documents are  accurately accomplished  and submitted promptly  after  assessment',
        '\u2022 Rating Sheets',
        '\u2022 CARS',
        '\u2022 Attendance Sheet',
        '\u2022 RWAC',
        '\u2022 Application Forms with SAGs',
        '\u2022 Assessor\u2019s Guide & Specific Instruction to Candidate',
      ],
    ];

  /// Build a cell with proper borders (no doubling).
  /// [isLastInRow] — draw right border.
  /// [isLastRow] — draw bottom border.
  Widget _cell({
    required double width,
    required double height,
    Widget? child,
    Color bg = Colors.transparent,
    bool isLastInRow = false,
    bool isLastRow = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: _black, width: _bw),
          left: BorderSide(color: _black, width: _bw),
          right: isLastInRow ? BorderSide(color: _black, width: _bw) : BorderSide.none,
          bottom: isLastRow ? BorderSide(color: _black, width: _bw) : BorderSide.none,
        ),
      ),
      padding: _cellPad,
      child: child,
    );
  }

  Widget _txt(String text, {TextStyle style = _f10, Alignment align = Alignment.centerLeft}) =>
      Align(alignment: align, child: Text(text, style: style));

  Widget _emptyCell(double w, double h, {bool last = false, bool isLastRow = false}) =>
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
            child: Center(child: ExcludeSemantics(child: RepaintBoundary(key: _previewKey, child: _buildDocument()))),
          ),
    );
  }

  Widget _buildDocument() {
    // A4 page with exact margins
    return Container(
      width: _pageW,
      color: Colors.white,
      padding: const EdgeInsets.only(top: _marginTop, left: _marginH, right: _marginH, bottom: _marginBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: form code (right-aligned, bold, 10pt) and rev (right-aligned, 10pt)
          const Align(alignment: Alignment.centerRight, child: Text('TESDA-OP-CO-05-F34', style: _f10b)),
          const Align(alignment: Alignment.centerRight, child: Text('Rev.No.00-03/08/17', style: _f10)),
          const SizedBox(height: 12),
          // Title (center, 12pt, bold)
          const Center(child: Text('REPORT ON ASSESSMENT PROCEEDINGS', style: _f12b)),
          const SizedBox(height: 12),
          // Main table — centered, 525.85pt wide
          Center(child: _buildTable()),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final rows = <Widget>[];
    final lastIdx = _rowHeights.length - 1;

    // Row 0: Center name | value (span 6)
    rows.add(Row(children: [
      _cell(width: _cLabel, height: _rowHeights[0], bg: _headerBg,
        child: _txt('Name of Competency Assessment Center', style: _f10b)),
      _cell(width: _cValue, height: _rowHeights[0], isLastInRow: true,
        child: _txt(' CAGAYAN STATE UNIVERSITY- CARIG CAMPUS', style: _f10b)),
    ]));

    // Row 1: Accreditation Number | value
    rows.add(Row(children: [
      _cell(width: _cLabel, height: _rowHeights[1], bg: _headerBg,
        child: _txt('Accreditation Number', style: _f10b)),
      _cell(width: _cValue, height: _rowHeights[1], isLastInRow: true,
        child: _txt(' ${_p('accreditationNumber')}', style: _f10)),
    ]));

    // Row 2: Title of Qualification | value
    rows.add(Row(children: [
      _cell(width: _cLabel, height: _rowHeights[2], bg: _headerBg,
        child: _txt('Title of Qualification', style: _f10b)),
      _cell(width: _cValue, height: _rowHeights[2], isLastInRow: true,
        child: _txt(' ${_p('qualificationTitle')}', style: _f10)),
    ]));

    // Row 3: Date of Assessment | value | No. of Candidates | value
    rows.add(Row(children: [
      _cell(width: _cLabel, height: _rowHeights[3], bg: _headerBg,
        child: _txt('Date of Assessment', style: _f10b)),
      _cell(width: _cDateVal, height: _rowHeights[3],
        child: _txt(' ${_p('assessmentDate')}', style: _f10)),
      _cell(width: _cNoLabel, height: _rowHeights[3], bg: _headerBg,
        child: _txt('No. of Candidates', style: _f10b)),
      _cell(width: _cNoVal, height: _rowHeights[3], isLastInRow: true,
        child: _txt(' ${_p('numberOfCandidates')}', style: _f10)),
    ]));

    // Row 4: Name of Competency Assessor | value
    rows.add(Row(children: [
      _cell(width: _cLabel, height: _rowHeights[4], bg: _headerBg,
        child: _txt('Name of Competency Assessor', style: _f10b)),
      _cell(width: _cValue, height: _rowHeights[4], isLastInRow: true,
        child: _txt(' ${_p('assessorName')}', style: _f10)),
    ]));

    // Row 5: Findings and Observations (full span)
    rows.add(Row(children: [
      _cell(width: _tableW, height: _rowHeights[5], bg: _headerBg, isLastInRow: true,
        child: _txt('Findings and Observations:', style: _f10b)),
    ]));

    // Row 6: Items | Yes | No | Areas for Improvement
    rows.add(Row(children: [
      _cell(width: _cItems, height: _rowHeights[6], bg: _headerBg,
        child: _txt('Items', style: _f10b, align: Alignment.center)),
      _cell(width: _cYes, height: _rowHeights[6], bg: _headerBg,
        child: _txt('Yes', style: _f10b, align: Alignment.center)),
      _cell(width: _cNo, height: _rowHeights[6], bg: _headerBg,
        child: _txt('No', style: _f10b, align: Alignment.center)),
      _cell(width: _cAreas, height: _rowHeights[6], bg: _headerBg, isLastInRow: true,
        child: _txt('Areas for Improvement', style: _f10b, align: Alignment.center)),
    ]));

    // Rows 7-18: 12 items
    for (int i = 0; i < 12; i++) {
      final ri = 7 + i;
      final isLast = ri == lastIdx;
      final lines = _items[i];
      final isBulleted = lines.length > 1;
      // Add 1mm (2.83pt) spacing between bullet lines for item 12
      // Bullet lines get 3-space left indent (≈21pt at Arial 10pt)
      final children = <Widget>[];
      for (int li = 0; li < lines.length; li++) {
        final isBullet = isBulleted && li > 0;
        if (isBullet) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(left: 21.0), // 3-space tab indent
              child: Text(lines[li], style: _f10),
            ),
          );
        } else {
          children.add(Text(lines[li], style: _f10));
        }
        if (li < lines.length - 1) {
          children.add(const SizedBox(height: 2.83)); // 1mm spacing
        }
      }
      rows.add(Row(children: [
        _cell(width: _cItems, height: _rowHeights[ri],
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
          isLastRow: isLast),
        _emptyCell(_cYes, _rowHeights[ri], isLastRow: isLast),
        _emptyCell(_cNo, _rowHeights[ri], isLastRow: isLast),
        _emptyCell(_cAreas, _rowHeights[ri], last: true, isLastRow: isLast),
      ]));
    }

    // Row 19: Narrative (full span) — 2mm spacing after label
    rows.add(Row(children: [
      _cell(width: _tableW, height: _rowHeights[19], isLastInRow: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5.67), // 2mm spacing
          child: _txt('Narrative:  (Recommended areas for improvement of items which are not covered or named above)', style: _f10b),
        ),
        isLastRow: false),
    ]));

    // Row 20: Prepared by (upper-left) | Date (upper-left) — 2mm spacing above
    // Underscore line and "Signature over Printed Name" are centered below
    // Date's underscore line is centered below "Date:"
    rows.add(Row(children: [
      _cell(width: _cPrepared, height: _rowHeights[20],
        child: Padding(
          padding: const EdgeInsets.only(top: 5.67), // 2mm spacing above
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.start, children: [
            _txt('Prepared by:', style: _f10),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.center,
              child: Text('____________________________________', style: _f10),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.center,
              child: Text('Signature over Printed Name (TESDA Rep)', style: _f10),
            ),
          ]),
        ), isLastRow: true),
      _cell(width: _cDateLine, height: _rowHeights[20], isLastInRow: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 5.67), // 2mm spacing above
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.start, children: [
            _txt('Date:', style: _f10),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.center,
              child: Text('_____________________', style: _f10),
            ),
          ]),
        ), isLastRow: true),
    ]));

    return SizedBox(
      width: _tableW,
      child: Column(children: rows),
    );
  }
}
