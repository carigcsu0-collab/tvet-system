import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';

/// Billing statement for a training batch: lists each trainee with the
/// training fee (from the center's fixed Training Fee) and the grand total.
/// Mirrors the manual "Billing Statement" spreadsheet.
class TrainingBillingScreen extends StatefulWidget {
  final Map<String, dynamic> batch;
  const TrainingBillingScreen({super.key, required this.batch});

  @override
  State<TrainingBillingScreen> createState() => _TrainingBillingScreenState();
}

class _TrainingBillingScreenState extends State<TrainingBillingScreen> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  double _fee = 0;
  List<Map<String, dynamic>> _trainees = [];
  double _total = 0;

  int get _batchId => widget.batch['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get('/training-batches/$_batchId/billing');
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _fee = (data['fee'] as num?)?.toDouble() ?? 0;
        _trainees = (data['trainees'] as List<dynamic>).cast<Map<String, dynamic>>();
        _total = (data['total'] as num?)?.toDouble() ?? 0;
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

  String _formatCurrency(double v) {
    final peso = String.fromCharCode(8369);
    return '$peso${NumberFormat('#,##0.00', 'en_US').format(v)}';
  }

  String _mi(dynamic middleName) {
    final m = middleName?.toString().trim() ?? '';
    return m.isEmpty ? '' : m[0].toUpperCase();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.isEmpty) return '';
    final plainDateMatch = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(text);
    if (plainDateMatch != null) return text;
    final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (isoMatch != null) return isoMatch.group(1)!;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.batch['center'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: Text('Billing Statement - ${widget.batch['qualification'] ?? ''}')),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(center?['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Training Fee: ${_formatCurrency(_fee)} per trainee', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: AppTheme.spaceSm),
                          Wrap(
                            spacing: AppTheme.spaceSm,
                            children: [
                              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: _load),
                              if (_exporting)
                                const Padding(padding: EdgeInsets.all(8), child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                              else
                                PopupMenuButton<String>(
                                  tooltip: 'Export',
                                  onSelected: (v) { if (v == 'excel') _exportExcel(); if (v == 'word') _exportWord(); if (v == 'pdf') _exportPdf(); },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'excel', child: ListTile(leading: Icon(Icons.table_view, size: 20), title: Text('Excel (.xlsx)'), dense: true, contentPadding: EdgeInsets.zero)),
                                    const PopupMenuItem(value: 'word', child: ListTile(leading: Icon(Icons.description, size: 20), title: Text('Word (.doc)'), dense: true, contentPadding: EdgeInsets.zero)),
                                    const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf, size: 20), title: Text('PDF (.pdf)'), dense: true, contentPadding: EdgeInsets.zero)),
                                  ],
                                  child: _exportButton(),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _trainees.isEmpty
                          ? const EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No trainees in this batch',
                              subtitle: 'Add trainees to this batch from the Attendance screen first',
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateColor.resolveWith((_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                                  columns: const [
                                    DataColumn(label: Text('No')),
                                    DataColumn(label: Text('Surname')),
                                    DataColumn(label: Text('Given Name')),
                                    DataColumn(label: Text('Ext')),
                                    DataColumn(label: Text('MI')),
                                    DataColumn(label: Text('Qualification')),
                                    DataColumn(label: Text('Date Started')),
                                    DataColumn(label: Text('Date Finished')),
                                    DataColumn(label: Text('Training Fee')),
                                  ],
                                  rows: [
                                    for (var i = 0; i < _trainees.length; i++)
                                      DataRow(cells: [
                                        DataCell(Text('${i + 1}')),
                                        DataCell(Text(_trainees[i]['last_name']?.toString() ?? '')),
                                        DataCell(Text(_trainees[i]['first_name']?.toString() ?? '')),
                                        DataCell(Text(_trainees[i]['extension_name']?.toString() ?? '')),
                                        DataCell(Text(_mi(_trainees[i]['middle_name']))),
                                        DataCell(Text(widget.batch['qualification']?.toString() ?? '')),
                                        DataCell(Text(_formatDate(widget.batch['date_started']))),
                                        DataCell(Text(_formatDate(widget.batch['date_finished']))),
                                        DataCell(Text(_formatCurrency(_fee))),
                                      ]),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    if (_trainees.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('TOTAL: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_formatCurrency(_total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.csuMaroon)),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _exportButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Export')]),
    );
  }

  (List<String>, List<List<String>>) _buildExportData() {
    final headers = ['No', 'Surname', 'Given Name', 'Ext', 'MI', 'Qualification', 'Date Started', 'Date Finished', 'Training Fee (Php)'];
    final data = <List<String>>[];
    for (var i = 0; i < _trainees.length; i++) {
      final t = _trainees[i];
      data.add([
        '${i + 1}',
        t['last_name']?.toString() ?? '',
        t['first_name']?.toString() ?? '',
        t['extension_name']?.toString() ?? '',
        _mi(t['middle_name']),
        widget.batch['qualification']?.toString() ?? '',
        _formatDate(widget.batch['date_started']),
        _formatDate(widget.batch['date_finished']),
        _fee.toStringAsFixed(2),
      ]);
    }
    return (headers, data);
  }

  Future<void> _saveFile(List<int> bytes, {required String fileName, required String extension}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save File', fileName: fileName, type: FileType.custom, allowedExtensions: [extension]);
      if (outputPath == null) return;
      await File(outputPath).writeAsBytes(bytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $outputPath')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], subject: fileName);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $fileName')));
  }

  String _exportFileName() => 'billing_statement_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (final row in data) { sheet.appendRow(row.map((c) => TextCellValue(c)).toList()); }
      sheet.appendRow([
        TextCellValue('TOTAL (Php)'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''),
        TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(_total.toStringAsFixed(2)),
      ]);
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode');
      await _saveFile(bytes, fileName: '${_exportFileName()}.xlsx', extension: 'xlsx');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  Future<void> _exportWord() async {
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      final amp = String.fromCharCode(38);
      String esc(String s) => s.replaceAll(amp, '${amp}amp;').replaceAll('<', '${amp}lt;').replaceAll('>', '${amp}gt;');
      final buf = StringBuffer()
        ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">')
        ..writeln('<head><meta charset="utf-8"><style>body{font-family:Arial;font-size:10pt}table{border-collapse:collapse;width:100%}th,td{border:1px solid #000;padding:4pt}th{background:#d9d9d9;font-weight:bold}</style></head><body>')
        ..writeln('<h2>Billing Statement</h2><h3>${esc(widget.batch['qualification']?.toString() ?? '')}</h3><table><thead><tr>');
      for (final h in headers) { buf.writeln('<th>${esc(h)}</th>'); }
      buf.writeln('</tr></thead><tbody>');
      for (final row in data) {
        buf.writeln('<tr>');
        for (final c in row) { buf.writeln('<td>${esc(c)}</td>'); }
        buf.writeln('</tr>');
      }
      buf.writeln('<tr><td colspan="8" style="text-align:right;font-weight:bold">TOTAL (Php)</td><td style="font-weight:bold">${esc(_total.toStringAsFixed(2))}</td></tr>');
      buf.writeln('</tbody></table></body></html>');
      await _saveFile(utf8.encode(buf.toString()), fileName: '${_exportFileName()}.doc', extension: 'doc');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      data.add(['', '', '', '', '', '', '', 'TOTAL (Php)', _total.toStringAsFixed(2)]);
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text('Billing Statement', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(widget.batch['qualification']?.toString() ?? '', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers, data: data, border: null,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 22, cellStyle: const pw.TextStyle(fontSize: 8),
            headerCellDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ));
      await _saveFile(await pdf.save(), fileName: '${_exportFileName()}.pdf', extension: 'pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }
}
