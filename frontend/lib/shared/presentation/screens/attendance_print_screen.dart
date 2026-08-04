// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/app_theme.dart';

class AttendancePrintScreen extends StatefulWidget {
  final Map<String, dynamic> center;
  final List<Map<String, dynamic>> selectedAssessees;
  final String assessorName;
  final String assessorAccreditationNumber;
  final String dateOfAssessment;
  final String qualification;
  final String acManagerName;

  const AttendancePrintScreen({
    super.key,
    required this.center,
    required this.selectedAssessees,
    this.assessorName = '',
    this.assessorAccreditationNumber = '',
    this.dateOfAssessment = '',
    this.qualification = '',
    this.acManagerName = '',
  });

  @override
  State<AttendancePrintScreen> createState() => _AttendancePrintScreenState();
}

class _AttendancePrintScreenState extends State<AttendancePrintScreen> {
  final _previewKey = GlobalKey();
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      // Load TESDA logo bytes
      final logoBytes = await rootBundle.load('assets/tesda_logo.png');
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

      // Load Arial fonts for PDF
      final arialRegular = pw.Font.ttf(
          (await rootBundle.load('assets/fonts/arial.ttf')));
      final arialBold = pw.Font.ttf(
          (await rootBundle.load('assets/fonts/arialbd.ttf')));
      final checkmarkFont = pw.Font.ttf(
          (await rootBundle.load('assets/fonts/checkmark.ttf')));

      final centerName = widget.center['name']?.toString() ?? '';
      final qualification = widget.qualification.isNotEmpty
          ? widget.qualification.toUpperCase()
          : (widget.center['qualifications'] as List<dynamic>? ?? [])
              .join(', ')
              .toUpperCase();

      final sorted =
          List<Map<String, dynamic>>.from(widget.selectedAssessees);
      sorted.sort((a, b) {
        final refA = a['reference_number']?.toString() ?? '';
        final refB = b['reference_number']?.toString() ?? '';
        return refA.compareTo(refB);
      });

      final pages = <List<Map<String, dynamic>>>[];
      for (var i = 0; i < sorted.length; i += 10) {
        pages.add(sorted.sublist(
            i, i + 10 > sorted.length ? sorted.length : i + 10));
      }
      if (pages.isEmpty) pages.add([]);

      final pdf = pw.Document();

      // 5 copies of attendance sheet
      for (int copy = 0; copy < 5; copy++) {
        for (final pageAssessees in pages) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(0),
              build: (context) => _buildPdfPage(
                pageAssessees,
                centerName,
                qualification,
                logoImage,
                arialRegular,
                arialBold,
              ),
            ),
          );
        }
      }

      // 2 copies of PEI (Page 1 / F29 only)
      for (int copy = 0; copy < 2; copy++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(0),
            build: (context) => _buildPeiPdfPage(
              'TESDA-OP-CO-04-F29',
              'Rev. No.00-05/04/23',
              '(To be accomplished by Candidates)',
              qualification,
              arialRegular,
              arialBold,
              checkmarkFont,
            ),
          ),
        );
      }

      // 1 copy of RAP
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (context) => _buildRapPdfPage(
            centerName,
            qualification,
            arialRegular,
            arialBold,
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  String _formatNamePdf(Map<String, dynamic> a) {
    final last = a['last_name']?.toString() ?? '';
    final first = a['first_name']?.toString() ?? '';
    final middle = a['middle_name']?.toString() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      final parts = [first, middle, last].where((p) => p.isNotEmpty).join(' ');
      return parts.toUpperCase();
    }
    return (a['name']?.toString() ?? '').toUpperCase();
  }

  pw.Widget _buildPdfPage(
    List<Map<String, dynamic>> assessees,
    String centerName,
    String qualification,
    pw.MemoryImage logoImage,
    pw.Font arial,
    pw.Font arialBold,
  ) {
    const black = PdfColor.fromInt(0xFF000000);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Header
          // Document code - top right
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('TESDA-OP-CO-05-F31',
                    style: pw.TextStyle(font: arial, fontSize: 8, color: black)),
                pw.Text('Rev. No. 00-03/08/17',
                    style: pw.TextStyle(font: arial, fontSize: 8, color: black)),
              ],
            ),
          ),
          pw.SizedBox(height: 3.78),
          // Logo
          pw.Center(
            child: pw.Image(logoImage, width: 60, height: 60),
          ),
          pw.SizedBox(height: 11.34),
          // Organization name
          pw.Text(
            'Technical Education and Skills Development Authority',
            style: pw.TextStyle(font: arial, fontSize: 10, color: black),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3.78),
          // Program
          pw.Text(
            'ASSESSMENT AND CERTIFICATION PROGRAM',
            style: pw.TextStyle(font: arial, fontSize: 10, color: black),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 11.34),
          // Attendance Sheet title - 11pt
          pw.Text(
            'ATTENDANCE SHEET',
            style: pw.TextStyle(font: arial, fontSize: 11, color: black),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 11.34),
          // Qualification - 11pt, underlined
          pw.Text(
            qualification,
            style: pw.TextStyle(
              font: arial,
              fontSize: 11,
              color: black,
              decoration: pw.TextDecoration.underline,
              decorationThickness: 2.0,
              decorationColor: black,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 15.12),
          // Info section
          pw.Table(
            border: pw.TableBorder.all(color: black, width: 0.375),
            columnWidths: {
              0: const pw.FixedColumnWidth(200),
              1: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: pw.Text(
                        'Name of Competency Assessment Center:',
                        style: pw.TextStyle(
                            font: arial, fontSize: 9, color: black)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: pw.Text(centerName,
                        style: pw.TextStyle(
                            font: arial, fontSize: 9, color: black)),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: pw.Text('Date of Assessment:',
                        style: pw.TextStyle(
                            font: arial, fontSize: 9, color: black)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: pw.Text(widget.dateOfAssessment,
                        style: pw.TextStyle(
                            font: arial, fontSize: 9, color: black)),
                  ),
                ],
              ),
            ],
          ),
          // Attendance table
          _buildPdfAttendanceTable(assessees, black, arial, arialBold),
          pw.SizedBox(height: 12),
          // Signature section
          _buildPdfSignatureSection(black, arial, arialBold),
        ],
      ),
    );
  }

  pw.Widget _buildPdfAttendanceTable(
    List<Map<String, dynamic>> assessees,
    PdfColor black,
    pw.Font arial,
    pw.Font arialBold,
  ) {
    final rowCount = assessees.length > 10 ? assessees.length : 10;
    return pw.Table(
      border: pw.TableBorder.all(color: black, width: 0.375),
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(3.0),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header
        pw.TableRow(
          children: [
            _pdfHeaderCell('No.', black, arialBold),
            _pdfHeaderCell("CANDIDATE'S NAME", black, arialBold),
            _pdfHeaderCell('Reference Number', black, arialBold),
            _pdfHeaderCell('Signature', black, arialBold),
            _pdfHeaderCell('Assessment Results', black, arialBold),
          ],
        ),
        // Body rows
        for (var i = 0; i < rowCount; i++)
          pw.TableRow(
            children: [
              _pdfBodyCell('${i + 1}.', black, arial),
              _pdfBodyCell(
                  i < assessees.length ? _formatNamePdf(assessees[i]) : '',
                  black, arial),
              _pdfBodyCell(
                  i < assessees.length
                      ? assessees[i]['reference_number']?.toString() ?? ''
                      : '',
                  black, arial),
              _pdfBodyCell('', black, arial),
              _pdfBodyCell('', black, arial),
            ],
          ),
        ],
      );
  }

  pw.Widget _pdfHeaderCell(String text, PdfColor black, pw.Font arialBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            font: arialBold, fontSize: 9, color: black),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfBodyCell(String text, PdfColor black, pw.Font arial) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: arial, fontSize: 8, color: black),
      ),
    );
  }

  pw.Widget _buildPdfSignatureSection(PdfColor black, pw.Font arial, pw.Font arialBold) {
    pw.Widget sigBox({
      required String title,
      required String name,
      required bool showAccreditation,
      String accreditationNumber = '',
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Title - upper left
            if (title.isNotEmpty)
              pw.Text(title,
                  style: pw.TextStyle(
                      font: arialBold,
                      fontSize: 8,
                      color: black),
                  textAlign: pw.TextAlign.left),
            pw.SizedBox(height: 20),
            // Name with underline - centered
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(name.toUpperCase(),
                      style: pw.TextStyle(font: arial, fontSize: 8, color: black),
                      textAlign: pw.TextAlign.center),
                  pw.Container(height: 1, color: black),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'Signature over Printed Name',
                style: pw.TextStyle(font: arial, fontSize: 8, color: black),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (showAccreditation) ...[
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Accreditation Number:',
                      style: pw.TextStyle(
                          font: arialBold,
                          fontSize: 8,
                          color: black)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(accreditationNumber,
                            style: pw.TextStyle(
                                font: arial, fontSize: 8, color: black)),
                        pw.Container(height: 1, color: black),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Use Table for the 2x2 grid to avoid IntrinsicHeight
    return pw.Table(
        border: pw.TableBorder.all(color: black, width: 0.375),
        columnWidths: {
          0: const pw.FlexColumnWidth(),
          1: const pw.FlexColumnWidth(),
        },
        children: [
          // Upper row: Assessor | TESDA Representative
          pw.TableRow(
            children: [
              sigBox(
                title: 'Assessors:',
                name: widget.assessorName,
                showAccreditation: true,
                accreditationNumber: widget.assessorAccreditationNumber,
              ),
              sigBox(
                title: 'TESDA Representative:',
                name: '',
                showAccreditation: false,
              ),
            ],
          ),
          // Lower row: Blank | AC Manager
          pw.TableRow(
            children: [
              sigBox(
                title: '',
                name: '',
                showAccreditation: true,
              ),
              sigBox(
                title: 'AC Manager:',
                name: widget.acManagerName,
                showAccreditation: false,
              ),
            ],
          ),
        ],
    );
  }

  // ============================================================
  // PEI PDF page builder (F29 / F30)
  // ============================================================
  pw.Widget _buildPeiPdfPage(
    String formCode,
    String revNo,
    String subtitle,
    String qualification,
    pw.Font arial,
    pw.Font arialBold,
    pw.Font checkmarkFont,
  ) {
    const black = PdfColor.fromInt(0xFF000000);
    const headerBg = PdfColor.fromInt(0xFFD9D9D9);

    pw.Widget cell(
      String text, {
      bool bold = false,
      bool center = false,
      PdfColor bg = const PdfColor(0, 0, 0, 0),
      double fontSize = 10,
      List<pw.Font> fontFallback = const [],
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: bold ? arialBold : arial,
            fontSize: fontSize,
            color: black,
            lineSpacing: 0,
            fontFallback: fontFallback,
          ),
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        ),
      );
    }

    pw.Widget emptyCell() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text('',
              style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
        );

    final f29Items = [
      '1. Physical appearance and composure\n(Pangkalahatang anyong pisikal at kung paano magdala sa sarili)',
      '2. Provided clear and concise instruction that is easily understood by the candidates\n(Nagbigay ng malinaw at maigsi na instruction na madaling maintindihan ng mga candidates.)',
      '3. Established good rapport and communication with candidates\n(Nagpakita ng magandang kaugnayan at maayos na pakikipag-usap sa mga candidates)',
      '4. Provided clear answers to queries and/or comments from the candidates\n(Nagbigay ng malinaw na mga sagot sa mga katanungan at komento mula sa mga candidates)',
      '5. Exhibited respectable behavior\n(Nagpakita ng kagalang-galang na pag-uugali)',
      '6. Explained the purpose and scope (context) of assessment\n(Ipinaliwanag ang layunin at saklaw (konteksto) ng assessment.)',
      '7. Provides fair, reliable and valid assessment decision\n(Kakayahang magbigay ng pantay, ugma at tamang desisyon sa resulta ng pagsusulit)',
    ];

    final f30Items = [
      '1. Planned and prepared the evidence gathering process\n(Nagplano at naghanda ng proseso ng pangangalap ng ebidensya para sa assessment)',
      '2. Provided allowable/reasonable adjustments in the assessment procedure\n(Nagbigay ng mga konsiderasyon/makatwirang pagsasaayos sa pamamaraan ng assessment)',
      '3. Collected appropriate evidence during the conduct of assessment\n(Nangalap at sumuri ng mga tamang ebidensya habang nagbibigay ng assessment)',
      '4. Provided clear and constructive feedback on the assessment decision\n(Nagbigay ng malinaw at tamang kaukulang opinyon sa resulta ng assessment)',
      '5. Provided fair, reliable and valid assessment decision\n(Kakayahang magbigay ng pantay, ugma at tamang desisyon sa resulta ng pagsusulit)',
    ];

    final items = formCode.contains('F29') ? f29Items : f30Items;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 66, vertical: 63),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Form code and rev
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(formCode,
                style: pw.TextStyle(font: arialBold, fontSize: 12, color: black)),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(revNo,
                style: pw.TextStyle(font: arial, fontSize: 12, color: black)),
          ),
          pw.SizedBox(height: 8),
          // Title
          pw.Center(
            child: pw.Text('PERFORMANCE EVALUATION INSTRUMENT',
                style: pw.TextStyle(font: arial, fontSize: 12, color: black)),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(subtitle,
                style: pw.TextStyle(font: arial, fontSize: 12, color: black)),
          ),
          pw.SizedBox(height: 8),
          // Main table
          _buildPeiMainTable(
            items,
            cell,
            emptyCell,
            black,
            headerBg,
            arial,
            arialBold,
            checkmarkFont,
            formCode.contains('F29'),
          ),
          pw.SizedBox(height: 8),
          // FOR TESDA USE ONLY table
          _buildPeiTesdaTable(black, headerBg, arial, arialBold, cell, checkmarkFont),
          pw.SizedBox(height: 6),
          // Footnote
          pw.Text(
            formCode.contains('F29')
                ? '*Shall be accomplished by two (2) candidates per assessment schedule. The candidates shall be 1 Competent and 1 Not Yet Competent'
                : '*Shall be accomplished by the AC Manager per assessment schedule.',
            style: pw.TextStyle(font: arial, fontSize: 12, color: black),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPeiMainTable(
    List<String> items,
    pw.Widget Function(String, {bool bold, bool center, PdfColor bg, double fontSize, List<pw.Font> fontFallback}) cell,
    pw.Widget Function() emptyCell,
    PdfColor black,
    PdfColor headerBg,
    pw.Font arial,
    pw.Font arialBold,
    pw.Font checkmarkFont,
    bool isF29,
  ) {
    const labelW = 116.85;
    const valueW = 345.6;
    const mainW = 462.45;
    const itemW = 342.95;
    const ratingW = 119.5;
    const rate5W = 23.8;
    const rateW = 23.9;
    const rate1W = 24.0;
    const scaleLblW = 92.6;
    const scale1W = 131.9;
    const scale2W = 73.4;
    const scale3W = 45.05;
    const scale4W = 119.5;
    const finalLblW = 246.0;
    const finalValW = 216.45;

    final respValW = isF29 ? 148.65 : 162.15;
    final dateLblW = isF29 ? 85.5 : 81.0;
    final dateValW = isF29 ? 111.45 : 102.45;

    final itemHeights = isF29
        ? <double>[24.05, 35.6, 35.7, 35.6, 24.05, 25.15, 35.6]
        : <double>[35.6, 48.35, 40.0, 49.45, 35.6];

    const h0 = 21.55;
    const h1 = 21.7;
    const h2 = 26.35;
    const h3 = 22.05;
    const h4 = 30.95;
    const h5 = 20.5;
    const h6 = 15.2;
    const hSub = 20.35;
    const hFinal = 20.35;
    const hSig = 20.5;

    final rows = <List<pw.Widget>>[];

    // R0: Assessor's Name | value
    rows.add([
      pw.Container(
        width: labelW,
        height: h0,
        decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)),
        child: cell("Assessor’s Name", bold: true, fontSize: 12),
      ),
      pw.Container(
        width: valueW,
        height: h0,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: cell(' ${widget.assessorName}', fontSize: 10),
      ),
    ]);

    // R1: Qualification | value
    rows.add([
      pw.Container(
        width: labelW,
        height: h1,
        decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)),
        child: cell('Qualification', bold: true, fontSize: 12),
      ),
      pw.Container(
        width: valueW,
        height: h1,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: cell(' ${widget.qualification}', fontSize: 10),
      ),
    ]);

    // R2: Name of Respondent | value | Date Accomplished | value
    rows.add([
      pw.Container(
        width: labelW,
        height: h2,
        decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)),
        child: cell('Name of Respondent', fontSize: 10),
      ),
      pw.Container(
        width: respValW,
        height: h2,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: cell(' ', fontSize: 10),
      ),
      pw.Container(
        width: dateLblW,
        height: h2,
        decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)),
        child: cell('Date Accomplished', fontSize: 10),
      ),
      pw.Container(
        width: dateValW,
        height: h2,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: cell(' ', fontSize: 10),
      ),
    ]);

    // R3: INSTRUCTIONS
    rows.add([
      pw.Container(
        width: mainW,
        height: h3,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(text: 'INSTRUCTIONS: Put a tick (', style: pw.TextStyle(font: arialBold, fontSize: 10, color: black)),
                pw.TextSpan(text: '\u2713', style: pw.TextStyle(font: checkmarkFont, fontSize: 10, color: black)),
                pw.TextSpan(text: ') mark in the appropriate column', style: pw.TextStyle(font: arialBold, fontSize: 10, color: black)),
              ],
            ),
          ),
        ),
      ),
    ]);

    // R4: SCALE GUIDE
    rows.add([
      pw.Container(
        width: scaleLblW,
        height: h4,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: cell('SCALE GUIDE', fontSize: 10),
      ),
      pw.Container(
        width: scale1W,
        height: h4,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('5\u2013 Very Satisfactory', style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
              pw.Text('4 \u2013 Satisfactory', style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
            ],
          ),
        ),
      ),
      pw.Container(
        width: scale2W,
        height: h4,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('3 \u2013 Good', style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
              pw.Text('2 \u2013 Fair', style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
            ],
          ),
        ),
      ),
      pw.Container(
        width: scale3W,
        height: h4,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: emptyCell(),
      ),
      pw.Container(
        width: scale4W,
        height: h4,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)),
        child: cell('1 – Poor', fontSize: 10),
      ),
    ]);

    // R5: ITEM | RATING
    rows.add([
      pw.Container(
        width: itemW,
        height: h5,
        decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)),
        child: cell('ITEM', bold: true, center: true, fontSize: 12),
      ),
      pw.Container(
        width: ratingW,
        height: h5,
        decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)),
        child: cell('RATING', bold: true, center: true, fontSize: 12),
      ),
    ]);

    // R6: empty | 5 4 3 2 1
    rows.add([
      pw.Container(width: itemW, height: h6, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
      pw.Container(width: rate5W, height: h6, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: cell('5', center: true, fontSize: 12)),
      pw.Container(width: rateW, height: h6, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: cell('4', center: true, fontSize: 12)),
      pw.Container(width: rateW, height: h6, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: cell('3', center: true, fontSize: 12)),
      pw.Container(width: rateW, height: h6, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: cell('2', center: true, fontSize: 12)),
      pw.Container(width: rate1W, height: h6, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: cell('1', center: true, fontSize: 12)),
    ]);

    // Item rows
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final itemHeight = i < itemHeights.length ? itemHeights[i] : 35.0;
      rows.add([
        pw.Container(width: itemW, height: itemHeight, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: cell(item, fontSize: 10)),
        pw.Container(width: rate5W, height: itemHeight, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
        pw.Container(width: rateW, height: itemHeight, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
        pw.Container(width: rateW, height: itemHeight, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
        pw.Container(width: rateW, height: itemHeight, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
        pw.Container(width: rate1W, height: itemHeight, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
      ]);
    }

    // Sub-score
    rows.add([
      pw.Container(width: itemW, height: hSub, decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)), child: cell('Sub - score', center: true, fontSize: 10)),
      pw.Container(width: rate5W, height: hSub, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
      pw.Container(width: rateW, height: hSub, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
      pw.Container(width: rateW, height: hSub, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
      pw.Container(width: rateW, height: hSub, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
      pw.Container(width: rate1W, height: hSub, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
    ]);

    // FINAL RATING
    rows.add([
      pw.Container(width: finalLblW, height: hFinal, decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)), child: cell('FINAL RATING', bold: true, fontSize: 10)),
      pw.Container(width: finalValW, height: hFinal, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: cell(' ', bold: true, center: true, fontSize: 10)),
    ]);

    // Signature of Respondent
    rows.add([
      pw.Container(width: finalLblW, height: hSig, decoration: pw.BoxDecoration(color: headerBg, border: pw.Border.all(color: black, width: 0.5)), child: cell('Signature of Respondent', bold: true, fontSize: 10)),
      pw.Container(width: finalValW, height: hSig, decoration: pw.BoxDecoration(border: pw.Border.all(color: black, width: 0.5)), child: emptyCell()),
    ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows.map((r) => pw.Row(children: r)).toList(),
    );
  }

  pw.Widget _buildPeiTesdaTable(
    PdfColor black,
    PdfColor headerBg,
    pw.Font arial,
    pw.Font arialBold,
    pw.Widget Function(String, {bool bold, bool center, PdfColor bg, double fontSize, List<pw.Font> fontFallback}) cell,
    pw.Font checkmarkFont,
  ) {
    const t0 = 11.8;
    const t1 = 120.3;
    const t2 = 114.8;
    const t3 = 216.45;
    const tW = t0 + t1 + t2 + t3;
    const h0 = 24.55;
    const h1 = 38.7;
    const h2 = 15.65;
    const h3 = 27.6;
    const thick = 1.0;

    pw.BoxDecoration b({
      bool top = false,
      bool left = false,
      bool right = false,
      bool bottom = false,
      double bw = 0.5,
      PdfColor? bg,
    }) => pw.BoxDecoration(
          color: bg,
          border: pw.Border(
            top: top ? pw.BorderSide(color: black, width: 0.5) : pw.BorderSide.none,
            left: left ? pw.BorderSide(color: black, width: 0.5) : pw.BorderSide.none,
            right: right ? pw.BorderSide(color: black, width: 0.5) : pw.BorderSide.none,
            bottom: bottom ? pw.BorderSide(color: black, width: bw) : pw.BorderSide.none,
          ),
        );

    // Helper: draw a checkbox square (replaces font-dependent ☐ glyph)
    pw.Widget checkboxLabel(String label) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 7,
              height: 7,
              margin: const pw.EdgeInsets.only(right: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: black, width: 0.5),
              ),
            ),
            pw.Text(label, style: pw.TextStyle(font: arial, fontSize: 9, color: black)),
          ],
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // R0: small cell (no right) | FOR TESDA USE ONLY (no left, thick bottom)
        pw.Row(children: [
          pw.Container(width: t0, height: h0, decoration: b(top: true, left: true, bottom: true, bw: thick), child: cell(' ', fontSize: 10)),
          pw.Container(
            width: t1 + t2 + t3,
            height: h0,
            decoration: b(top: true, right: true, bottom: true, bw: thick, bg: headerBg),
            child: cell('FOR TESDA USE ONLY', bold: true, center: true, fontSize: 10),
          ),
        ]),
        // R1: EVALUATOR'S REMARKS (full span, thick top, 2mm left padding, top-left)
        pw.Row(children: [
          pw.Container(
            width: tW,
            height: h1,
            decoration: b(top: true, left: true, right: true, bottom: true, bw: thick),
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(left: 5.67, top: 3), // 2mm left
              child: pw.Align(
                alignment: pw.Alignment.topLeft,
                child: pw.Text('EVALUATOR\u2019S REMARKS:', style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
              ),
            ),
          ),
        ]),
        // R2: [empty] | RECOMMENDATION: | [empty] | [empty] — no internal verticals, no bottom
        pw.Row(children: [
          pw.Container(width: t0, height: h2, decoration: b(top: true, left: true), child: cell(' ', fontSize: 10)),
          pw.Container(width: t1, height: h2, decoration: b(top: true), child: cell('RECOMMENDATION:', fontSize: 10)),
          pw.Container(width: t2, height: h2, decoration: b(top: true), child: cell(' ', fontSize: 10)),
          pw.Container(width: t3, height: h2, decoration: b(top: true, right: true), child: cell(' ', fontSize: 10)),
        ]),
        // R3: small | For re-accreditation | YES / NO (stacked) | For further review
        // No top, no internal verticals
        pw.Row(children: [
          pw.Container(width: t0, height: h3, decoration: b(left: true, bottom: true), child: cell(' ', fontSize: 10)),
          pw.Container(width: t1, height: h3, decoration: b(bottom: true), child: cell('For re-accreditation', fontSize: 10)),
          pw.Container(
            width: t2,
            height: h3,
            decoration: b(bottom: true),
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  checkboxLabel('YES'),
                  checkboxLabel('NO'),
                ],
              ),
            ),
          ),
          pw.Container(width: t3, height: h3, decoration: b(right: true, bottom: true), child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: pw.Align(
                alignment: pw.Alignment.topCenter,
                child: checkboxLabel('For further review'),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // RAP PDF page builder (F34)
  // ============================================================
  pw.Widget _buildRapPdfPage(
    String centerName,
    String qualification,
    pw.Font arial,
    pw.Font arialBold,
  ) {
    const black = PdfColor.fromInt(0xFF000000);
    const headerBg = PdfColor.fromInt(0xFFD9D9D9);
    const rapBorder = 0.375;

    const tableW = 525.85;
    const cLabel = 202.05;
    const cValue = 323.8;
    const cDateVal = 136.75;
    const cNoLabel = 121.15;
    const cNoVal = 65.9;
    const cItems = 292.5;
    const cYes = 36.2;
    const cNo = 35.25;
    const cAreas = 161.9;
    const cPrepared = 292.5;
    const cDateLine = 233.35;

    pw.Widget labelCell(String text, double w, double h, {bool isLastRow = false}) {
      return pw.Container(
        width: w,
        height: h,
        decoration: pw.BoxDecoration(
          color: headerBg,
          border: pw.Border(
            top: pw.BorderSide(color: black, width: rapBorder),
            left: pw.BorderSide(color: black, width: rapBorder),
            bottom: isLastRow ? pw.BorderSide(color: black, width: rapBorder) : pw.BorderSide.none,
          ),
        ),
        padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(text,
              style: pw.TextStyle(font: arialBold, fontSize: 10, color: black)),
        ),
      );
    }

    pw.Widget valueCell(String text, double w, double h, {bool last = false, bool isLastRow = false}) {
      return pw.Container(
        width: w,
        height: h,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: black, width: rapBorder),
            left: pw.BorderSide(color: black, width: rapBorder),
            right: last ? pw.BorderSide(color: black, width: rapBorder) : pw.BorderSide.none,
            bottom: isLastRow ? pw.BorderSide(color: black, width: rapBorder) : pw.BorderSide.none,
          ),
        ),
        padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(text,
              style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
        ),
      );
    }

    pw.Widget emptyCell(double w, double h, {bool last = false, bool isLastRow = false}) {
      return pw.Container(
        width: w,
        height: h,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: black, width: rapBorder),
            left: pw.BorderSide(color: black, width: rapBorder),
            right: last ? pw.BorderSide(color: black, width: rapBorder) : pw.BorderSide.none,
            bottom: isLastRow ? pw.BorderSide(color: black, width: rapBorder) : pw.BorderSide.none,
          ),
        ),
        padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
        child: pw.Text('',
            style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
      );
    }

    final rapItems = [
      '1. Competency Assessor has a signed Letter of Appointment',
      '2. Attendance of the candidates is checked and Admission Slips are verified and collected',
      '3. Supplies and materials are available during the conduct of assessment',
      '4. Tools and equipment are available and in good working conditions',
      '5. Assessment starts on time',
      '6. Conduct of assessment is in accordance with the methods identified in the CATs',
      '7. Projects produced by the candidates are in accordance with the requirements in the CATs.',
      '8. Candidates are provided with clear and constructive feedback on the assessment decision (one-on-one)',
      '9. Assessor has the ability to manage the competency assessment proceedings',
      '10. Complaints of candidates are properly addressed and handled by the Assessor & the AC, when applicable',
      '11. Assessment Packages issued to the Assessor are completely returned upon completion of assessment',
      '12. Assessment-related documents are accurately accomplished and submitted promptly after assessment',
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 36.0, left: 34.725, right: 34.725, bottom: 72),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('TESDA-OP-CO-05-F34',
                style: pw.TextStyle(font: arialBold, fontSize: 10, color: black)),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Rev.No.00-03/08/17',
                style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text('REPORT ON ASSESSMENT PROCEEDINGS',
                style: pw.TextStyle(font: arialBold, fontSize: 12, color: black)),
          ),
          pw.SizedBox(height: 12),
          // Main table
          pw.Center(
            child: pw.SizedBox(
              width: tableW,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Row 0: Center name
                  pw.Row(children: [
                    labelCell('Name of Competency Assessment Center', cLabel, 28.8),
                    valueCell(' $centerName', cValue, 28.8, last: true),
                  ]),
                  // Row 1: Accreditation Number
                  pw.Row(children: [
                    labelCell('Accreditation Number', cLabel, 16.05),
                    valueCell(' ${widget.center['accreditation_number']?.toString() ?? ''}', cValue, 16.05, last: true),
                  ]),
                  // Row 2: Title of Qualification
                  pw.Row(children: [
                    labelCell('Title of Qualification', cLabel, 15.95),
                    valueCell(' ${widget.qualification}', cValue, 15.95, last: true),
                  ]),
                  // Row 3: Date of Assessment | No. of Candidates
                  pw.Row(children: [
                    labelCell('Date of Assessment', cLabel, 19.1),
                    valueCell(' ${widget.dateOfAssessment}', cDateVal, 19.1),
                    labelCell('No. of Candidates', cNoLabel, 19.1),
                    valueCell('', cNoVal, 19.1, last: true),
                  ]),
                  // Row 4: Name of Competency Assessor
                  pw.Row(children: [
                    labelCell('Name of Competency Assessor', cLabel, 14.8),
                    valueCell(' ${widget.assessorName}', cValue, 14.8, last: true),
                  ]),
                  // Row 5: Findings and Observations
                  pw.Container(
                    width: tableW,
                    height: 14.8,
                    decoration: pw.BoxDecoration(
                      color: headerBg,
                      border: pw.Border(
                        top: pw.BorderSide(color: black, width: rapBorder),
                        left: pw.BorderSide(color: black, width: rapBorder),
                        right: pw.BorderSide(color: black, width: rapBorder),
                      ),
                    ),
                    padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text('Findings and Observations:',
                          style: pw.TextStyle(font: arialBold, fontSize: 10, color: black)),
                    ),
                  ),
                  // Row 6: Column headers
                  pw.Row(children: [
                    pw.Container(
                      width: cItems,
                      height: 23.0,
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        border: pw.Border(
                          top: pw.BorderSide(color: black, width: rapBorder),
                          left: pw.BorderSide(color: black, width: rapBorder),
                        ),
                      ),
                      padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
                      child: pw.Center(child: pw.Text('Items',
                          style: pw.TextStyle(font: arialBold, fontSize: 10, color: black))),
                    ),
                    pw.Container(
                      width: cYes,
                      height: 23.0,
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        border: pw.Border(
                          top: pw.BorderSide(color: black, width: rapBorder),
                          left: pw.BorderSide(color: black, width: rapBorder),
                        ),
                      ),
                      padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
                      child: pw.Center(child: pw.Text('Yes',
                          style: pw.TextStyle(font: arialBold, fontSize: 10, color: black))),
                    ),
                    pw.Container(
                      width: cNo,
                      height: 23.0,
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        border: pw.Border(
                          top: pw.BorderSide(color: black, width: rapBorder),
                          left: pw.BorderSide(color: black, width: rapBorder),
                        ),
                      ),
                      padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
                      child: pw.Center(child: pw.Text('No',
                          style: pw.TextStyle(font: arialBold, fontSize: 10, color: black))),
                    ),
                    pw.Container(
                      width: cAreas,
                      height: 23.0,
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        border: pw.Border(
                          top: pw.BorderSide(color: black, width: rapBorder),
                          left: pw.BorderSide(color: black, width: rapBorder),
                          right: pw.BorderSide(color: black, width: rapBorder),
                        ),
                      ),
                      padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
                      child: pw.Center(child: pw.Text('Areas for Improvement',
                          style: pw.TextStyle(font: arialBold, fontSize: 10, color: black))),
                    ),
                  ]),
                  // Rows 7-18: 12 items
                  for (int i = 0; i < 12; i++) ...[
                    pw.Row(children: [
                      pw.Container(
                        width: cItems,
                        height: 28.1,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: black, width: rapBorder),
                            left: pw.BorderSide(color: black, width: rapBorder),
                          ),
                        ),
                        padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 0.3),
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(rapItems[i],
                              style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
                        ),
                      ),
                      emptyCell(cYes, 28.1),
                      emptyCell(cNo, 28.1),
                      emptyCell(cAreas, 28.1, last: true),
                    ]),
                  ],
                  // Row 19: Narrative
                  pw.Container(
                    width: tableW,
                    height: 36.92,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: black, width: rapBorder),
                        left: pw.BorderSide(color: black, width: rapBorder),
                        right: pw.BorderSide(color: black, width: rapBorder),
                      ),
                    ),
                    padding: const pw.EdgeInsets.fromLTRB(5.2, 0.3, 2.3, 5.67),
                    child: pw.Align(
                      alignment: pw.Alignment.topLeft,
                      child: pw.Text(
                          'Narrative:  (Recommended areas for improvement of items which are not covered or named above)',
                          style: pw.TextStyle(font: arialBold, fontSize: 10, color: black)),
                    ),
                  ),
                  // Row 20: Prepared by | Date
                  pw.Row(children: [
                    pw.Container(
                      width: cPrepared,
                      height: 57.72,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: black, width: rapBorder),
                          left: pw.BorderSide(color: black, width: rapBorder),
                          bottom: pw.BorderSide(color: black, width: rapBorder),
                        ),
                      ),
                      padding: const pw.EdgeInsets.fromLTRB(5.2, 5.67, 2.3, 0.3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Prepared by:',
                              style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
                          pw.SizedBox(height: 4),
                          pw.Center(child: pw.Text('____________________________________',
                              style: pw.TextStyle(font: arial, fontSize: 10, color: black))),
                          pw.SizedBox(height: 4),
                          pw.Center(child: pw.Text('Signature over Printed Name (TESDA Rep)',
                              style: pw.TextStyle(font: arial, fontSize: 10, color: black))),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: cDateLine,
                      height: 57.72,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: black, width: rapBorder),
                      ),
                      padding: const pw.EdgeInsets.fromLTRB(5.2, 5.67, 2.3, 0.3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Date:',
                              style: pw.TextStyle(font: arial, fontSize: 10, color: black)),
                          pw.SizedBox(height: 4),
                          pw.Center(child: pw.Text('_____________________',
                              style: pw.TextStyle(font: arial, fontSize: 10, color: black))),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerName = widget.center['name']?.toString() ?? '';
    final qualification = widget.qualification.isNotEmpty
        ? widget.qualification.toUpperCase()
        : (widget.center['qualifications'] as List<dynamic>? ?? [])
            .join(', ')
            .toUpperCase();

    final sorted = List<Map<String, dynamic>>.from(widget.selectedAssessees);
    sorted.sort((a, b) {
      final refA = a['reference_number']?.toString() ?? '';
      final refB = b['reference_number']?.toString() ?? '';
      return refA.compareTo(refB);
    });

    final pages = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < sorted.length; i += 10) {
      pages.add(
          sorted.sublist(i, i + 10 > sorted.length ? sorted.length : i + 10));
    }
    if (pages.isEmpty) pages.add([]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview (5 Attendance, 2 PEI, 1 RAP)'),
        actions: [
          IconButton(
            icon: _printing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
            onPressed: _printing ? null : _print,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Center(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              key: _previewKey,
              child: Container(
                width: 595,
                color: Colors.white,
                child: Column(
                  children: pages
                      .map((page) => AttendanceSheetPage(
                            assessees: page,
                            centerName: centerName,
                            qualification: qualification,
                            dateOfAssessment: widget.dateOfAssessment,
                            assessorName: widget.assessorName,
                            assessorAccreditationNumber:
                                widget.assessorAccreditationNumber,
                            acManagerName: widget.acManagerName,
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AttendanceSheetPage - Full page widget
// ============================================================

class AttendanceSheetPage extends StatelessWidget {
  final List<Map<String, dynamic>> assessees;
  final String centerName;
  final String qualification;
  final String dateOfAssessment;
  final String assessorName;
  final String assessorAccreditationNumber;
  final String acManagerName;

  const AttendanceSheetPage({
    super.key,
    required this.assessees,
    required this.centerName,
    required this.qualification,
    required this.dateOfAssessment,
    this.assessorName = '',
    this.assessorAccreditationNumber = '',
    this.acManagerName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AttendanceHeader(qualification: qualification),
          const SizedBox(height: 12),
          AssessmentInformationSection(
            centerName: centerName,
            dateOfAssessment: dateOfAssessment,
          ),
          const SizedBox(height: 8),
          AttendanceTable(assessees: assessees),
          const SizedBox(height: 12),
          SignatureSection(
            assessorName: assessorName,
            assessorAccreditationNumber: assessorAccreditationNumber,
            acManagerName: acManagerName,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AttendanceHeader - Document code, logo, title, qualification
// ============================================================

class AttendanceHeader extends StatelessWidget {
  final String qualification;

  const AttendanceHeader({super.key, required this.qualification});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Document code - top right
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text(
                'TESDA-OP-CO-05-F31',
                style: TextStyle(
                    fontSize: 8,
                    fontFamily: 'Arial',
                    color: Colors.black),
              ),
              Text(
                'Rev. No. 00-03/08/17',
                style: TextStyle(
                    fontSize: 8,
                    fontFamily: 'Arial',
                    color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3.78),
        // TESDA Logo - centered
        Image.asset(
          'assets/tesda_logo.png',
          height: 60,
          width: 60,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 11.34),
        // Organization name
        const Text(
          'Technical Education and Skills Development Authority',
          style: TextStyle(
              fontSize: 10,
              fontFamily: 'Arial',
              color: Colors.black),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3.78),
        // Program
        const Text(
          'ASSESSMENT AND CERTIFICATION PROGRAM',
          style: TextStyle(
              fontSize: 10,
              fontFamily: 'Arial',
              color: Colors.black),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 11.34),
        // Attendance Sheet title - not bold, 11pt
        const Text(
          'ATTENDANCE SHEET',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'Arial',
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 11.34),
        // Qualification name - 11pt
        Text(
          qualification,
          style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Arial',
              color: Colors.black),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15.12),
        // Centered horizontal line
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.black,
        ),
      ],
    );
  }
}

// ============================================================
// AssessmentInformationSection - 2-row bordered table
// ============================================================

class AssessmentInformationSection extends StatelessWidget {
  final String centerName;
  final String dateOfAssessment;

  const AssessmentInformationSection({
    super.key,
    required this.centerName,
    required this.dateOfAssessment,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(200),
        1: FlexColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            _InfoCell('Name of Competency Assessment Center:'),
            _InfoCell(centerName),
          ],
        ),
        TableRow(
          children: [
            _InfoCell('Date of Assessment:'),
            _InfoCell(dateOfAssessment),
          ],
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String text;
  const _InfoCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 9,
            fontFamily: 'Arial',
            color: Colors.black),
      ),
    );
  }
}

// ============================================================
// AttendanceTable - Main attendance table with dynamic rows
// ============================================================

class AttendanceTable extends StatelessWidget {
  final List<Map<String, dynamic>> assessees;

  const AttendanceTable({super.key, required this.assessees});

  @override
  Widget build(BuildContext context) {
    final rowCount = assessees.length > 10 ? assessees.length : 10;
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(25),
        1: FlexColumnWidth(3.0),
        2: FlexColumnWidth(1.8),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
      },
      children: [
        // Header row - no background color
        const TableRow(
          children: [
            _TableHeaderCell('No.'),
            _TableHeaderCell("CANDIDATE'S NAME"),
            _TableHeaderCell('Reference Number'),
            _TableHeaderCell('Signature'),
            _TableHeaderCell('Assessment Results'),
          ],
        ),
        // Dynamic rows
        for (var i = 0; i < rowCount; i++)
          TableRow(
            children: [
              _TableBodyCell('${i + 1}.'),
              _TableBodyCell(i < assessees.length
                  ? _formatName(assessees[i])
                  : ''),
              _TableBodyCell(i < assessees.length
                  ? assessees[i]['reference_number']?.toString() ?? ''
                  : ''),
              const _TableBodyCell(''),
              const _TableBodyCell(''),
            ],
          ),
      ],
    );
  }

  String _formatName(Map<String, dynamic> a) {
    final last = a['last_name']?.toString() ?? '';
    final first = a['first_name']?.toString() ?? '';
    final middle = a['middle_name']?.toString() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      final parts = [first, middle, last].where((p) => p.isNotEmpty).join(' ');
      return parts.toUpperCase();
    }
    return (a['name']?.toString() ?? '').toUpperCase();
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TableBodyCell extends StatelessWidget {
  final String text;
  const _TableBodyCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 8,
            fontFamily: 'Arial',
            color: Colors.black),
      ),
    );
  }
}

// ============================================================
// SignatureSection - 2x2 bordered grid
// ============================================================

class SignatureSection extends StatelessWidget {
  final String assessorName;
  final String assessorAccreditationNumber;
  final String acManagerName;

  const SignatureSection({
    super.key,
    this.assessorName = '',
    this.assessorAccreditationNumber = '',
    this.acManagerName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        children: [
          // Upper row: Assessor | TESDA Representative
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SignatureBox(
                    title: 'Assessors:',
                    name: assessorName,
                    showAccreditation: true,
                    accreditationNumber: assessorAccreditationNumber,
                  ),
                ),
                Container(width: 1, color: Colors.black),
                Expanded(
                  child: _SignatureBox(
                    title: 'TESDA Representative:',
                    name: '',
                    showAccreditation: false,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.black),
          // Lower row: Blank | AC Manager
          IntrinsicHeight(
            child: Row(
              children: [
                const Expanded(
                  child: _SignatureBox(
                    title: '',
                    name: '',
                    showAccreditation: true,
                  ),
                ),
                Container(width: 1, color: Colors.black),
                Expanded(
                  child: _SignatureBox(
                    title: 'AC Manager:',
                    name: acManagerName,
                    showAccreditation: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureBox extends StatelessWidget {
  final String title;
  final String name;
  final bool showAccreditation;
  final String accreditationNumber;

  const _SignatureBox({
    required this.title,
    required this.name,
    required this.showAccreditation,
    this.accreditationNumber = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title - upper left corner
          Text(title,
              style: const TextStyle(
                  fontSize: 8,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              textAlign: TextAlign.left),
          const SizedBox(height: 20),
          // Name with underline - centered
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 8,
                        fontFamily: 'Arial',
                        color: Colors.black),
                    textAlign: TextAlign.center),
                Container(height: 1, color: Colors.black),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Center(
            child: Text(
              'Signature over Printed Name',
              style: TextStyle(
                  fontSize: 8,
                  fontFamily: 'Arial',
                  color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ),
          // Accreditation number - inline with underline
          if (showAccreditation) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text('Accreditation Number:',
                      style: const TextStyle(
                          fontSize: 8,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(accreditationNumber,
                          style: const TextStyle(
                              fontSize: 8,
                              fontFamily: 'Arial',
                              color: Colors.black)),
                      Container(height: 1, color: Colors.black),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
