// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/app_theme.dart';

class CenterReportPrintScreen extends StatefulWidget {
  final List<Map<String, dynamic>> centers;
  final Set<String> selectedColumns;
  final String reportTitle;

  const CenterReportPrintScreen({
    super.key,
    required this.centers,
    required this.selectedColumns,
    this.reportTitle = 'Center Report',
  });

  @override
  State<CenterReportPrintScreen> createState() => _CenterReportPrintScreenState();
}

class _CenterReportPrintScreenState extends State<CenterReportPrintScreen> {
  final _previewKey = GlobalKey();
  bool _printing = false;

  static const _allColumns = {
    'name': 'Center Name',
    'accreditation_number': 'Accreditation No.',
    'type': 'Type',
    'status': 'Status',
    'address': 'Address',
    'fee': 'Fee',
    'qualifications': 'Qualifications',
    'expiration_date': 'Expiration',
    'audit_date': 'Audit Date',
  };

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;

      final pdf = pw.Document();
      final imageProvider = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
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

  String _getCellValue(Map<String, dynamic> c, String key) {
    switch (key) {
      case 'name':
        return c['name']?.toString() ?? '';
      case 'accreditation_number':
        return c['accreditation_number']?.toString() ?? '';
      case 'type':
        final t = c['type']?.toString() ?? '';
        return t == 'assessment' ? 'Assessment' : 'Training';
      case 'status':
        return c['status']?.toString() ?? '';
      case 'address':
        return c['address']?.toString() ?? '';
      case 'fee':
        final type = c['type']?.toString() ?? '';
        final fee = type == 'assessment'
            ? c['assessment_fee']?.toString() ?? '0'
            : c['training_fee']?.toString() ?? '0';
        return '\u20B1$fee';
      case 'qualifications':
        final quals = c['qualifications'] as List<dynamic>? ?? [];
        return quals.join(', ');
      case 'expiration_date':
        return c['expiration_date']?.toString().split(' ').first ?? '';
      case 'audit_date':
        return c['audit_date']?.toString().split(' ').first ?? '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = _allColumns.keys
        .where((k) => widget.selectedColumns.contains(k))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Center Report Preview'),
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
                padding: const EdgeInsets.all(40),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/csu_logo.png',
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 4),
                          const Text('CAGAYAN STATE UNIVERSITY',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                          const Text('Carig Campus, Tuguegarao City',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black)),
                          const Text('TVET Office',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black)),
                        ],
                      ),
                    ),
                    const Divider(height: 16, thickness: 1),
                    Center(
                      child: Text(
                        widget.reportTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Table
                    Table(
                      border: TableBorder.all(
                        color: Colors.black,
                        width: 0.5,
                      ),
                      columnWidths: {
                        for (var i = 0; i < cols.length; i++)
                          i: const FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: [
                            for (final col in cols)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Text(
                                  _allColumns[col] ?? col,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ...widget.centers.map((c) {
                          return TableRow(
                            children: [
                              for (final col in cols)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  child: Text(
                                    _getCellValue(c, col),
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.black),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${widget.centers.length} center(s)',
                      style: const TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
