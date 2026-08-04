// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';

class PaymentSlipPrintScreen extends StatefulWidget {
  final Map<String, dynamic> slip;
  final String processingOfficer;
  final String processingOfficerDesignations;
  final List<Map<String, dynamic>> allQualifications;
  final Map<String, bool> selectedKeys;

  const PaymentSlipPrintScreen({
    super.key,
    required this.slip,
    this.processingOfficer = '',
    this.processingOfficerDesignations = '',
    this.allQualifications = const [],
    this.selectedKeys = const {},
  });

  @override
  State<PaymentSlipPrintScreen> createState() => _PaymentSlipPrintScreenState();
}

class _PaymentSlipPrintScreenState extends State<PaymentSlipPrintScreen> {
  final _previewKey = GlobalKey();
  bool _printing = false;

  // 8.5 x 13 inches (legal/Folio)
  static const _pageWidth = 8.5 * 72.0; // 612 pt
  static const _pageHeight = 13.0 * 72.0; // 936 pt

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      // Increment printed count
      await ApiClient.post('/payment-slips/${widget.slip['id']}/printed');

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
          pageFormat: const PdfPageFormat(_pageWidth, _pageHeight),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.Image(
              imageProvider,
              fit: pw.BoxFit.contain,
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Slip Preview'),
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
                width: _pageWidth,
                color: Colors.white,
                child: Wrap(
                  children: [
                    SizedBox(
                      width: _pageWidth / 2,
                      child: _buildSlip(0),
                    ),
                    SizedBox(
                      width: _pageWidth / 2,
                      child: _buildSlip(1),
                    ),
                    SizedBox(
                      width: _pageWidth / 2,
                      child: _buildSlip(2),
                    ),
                    SizedBox(
                      width: _pageWidth / 2,
                      child: _buildSlip(3),
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

  String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _buildSlip(int copyIndex) {
    final slip = widget.slip;
    final total = (slip['total_amount'] as num?)?.toDouble() ?? 0;
    final officer = widget.processingOfficer.isNotEmpty
        ? widget.processingOfficer
        : slip['officer_name']?.toString() ?? '';
    final officerDesignations = widget.processingOfficerDesignations.isNotEmpty
        ? widget.processingOfficerDesignations
        : slip['officer_designations']?.toString() ?? '';
    final studentId = slip['student_id']?.toString() ?? '';
    final course = slip['course']?.toString() ?? '';
    final lastName = slip['last_name']?.toString() ?? '';
    final firstName = slip['first_name']?.toString() ?? '';
    final middleName = slip['middle_name']?.toString() ?? '';

    // Build a map of qualification -> amount from saved items
    final savedAmounts = <String, double>{};
    for (final item in (slip['items'] as List<dynamic>? ?? [])) {
      final qual = (item as Map<String, dynamic>)['qualification']?.toString() ?? '';
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      savedAmounts[qual] = amount;
    }

    // Use all qualifications from the form, or fall back to saved items
    final allQuals = widget.allQualifications.isNotEmpty
        ? widget.allQualifications
        : (slip['items'] as List<dynamic>? ?? []).map((item) {
            final qual = (item as Map<String, dynamic>)['qualification']?.toString() ?? '';
            final amount = (item['amount'] as num?)?.toDouble() ?? 0;
            return <String, dynamic>{
              'key': qual,
              'qualification': qual,
              'fee': amount,
              'type': '',
              'center': '',
            };
          }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.3),
            width: 0.5,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - CSU logo + centered text
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/csu_logo.png',
                  height: 50,
                  width: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                const Text('Republic of the Philippines',
                    style: TextStyle(fontSize: 8, color: Colors.black)),
                const Text('CAGAYAN STATE UNIVERSITY',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                const Text('Carig Campus, Tuguegarao City',
                    style: TextStyle(fontSize: 9, color: Colors.black)),
                const Text('TVET Office',
                    style: TextStyle(
                        fontSize: 8, fontStyle: FontStyle.italic, color: Colors.black)),
              ],
            ),
          ),
          const Divider(height: 12, thickness: 1),
          // Title
          const Center(
            child: Text(
              'PAYMENT SLIP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Student info - filled in from form
          _infoRow('ID NUMBER', studentId),
          _infoRow('COURSE', course),
          _infoRow('LAST NAME', lastName),
          _infoRow('FIRST NAME', firstName),
          _infoRow('M.I', middleName),
          const SizedBox(height: 8),
          // Qualification table - all qualifications listed
          Table(
            border: TableBorder.all(
              color: Colors.black,
              width: 0.5,
            ),
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
            },
            children: [
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    child: Text('NC ASSESSMENT',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    child: Text('AMOUNT',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
              ...allQuals.map((q) {
                final qualLabel = q['qualification']?.toString() ?? '';
                final typeLabel = q['type']?.toString() ?? '';
                final fullLabel = typeLabel.isNotEmpty
                    ? '$qualLabel (${typeLabel == 'assessment' ? 'Assessment' : 'Training'})'
                    : qualLabel;
                final isSelected = widget.selectedKeys[q['key']] == true;
                final amount = isSelected
                    ? (q['fee'] as num?)?.toDouble() ?? 0
                    : (savedAmounts[fullLabel] ?? 0);
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(fullLabel,
                          style: const TextStyle(fontSize: 9, color: Colors.black)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(
                        amount > 0
                            ? '\u20B1${amount.toStringAsFixed(2)}'
                            : '0',
                        style: const TextStyle(fontSize: 9, color: Colors.black),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                );
              }),
              TableRow(
                children: [
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text('TOTAL',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      '\u20B1${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Approved by
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('APPROVED BY:',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 20),
              if (officer.isNotEmpty)
                Text(officer,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
              if (officerDesignations.isNotEmpty)
                Text(_titleCase(officerDesignations),
                    style: const TextStyle(
                        fontSize: 8, color: Colors.black)),
              const SizedBox(height: 2),
              Container(
                width: 120,
                height: 0.5,
                color: Colors.black,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(width: 4),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Container(
                  height: 14,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 9, color: Colors.black),
                  ),
                ),
                Container(
                  height: 0.5,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
