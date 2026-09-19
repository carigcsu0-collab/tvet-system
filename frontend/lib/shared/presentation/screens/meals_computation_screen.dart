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

/// Lunch & Snacks computation list.
/// Standalone records (not tied to training batches): enter the activity,
/// number of pax, days, and per-person rates; totals are computed as
///   lunch  = pax x days x lunch_rate
///   snacks = pax x days x snacks_per_day x snack_rate
class MealsComputationScreen extends StatefulWidget {
  const MealsComputationScreen({super.key});

  @override
  State<MealsComputationScreen> createState() => MealsComputationScreenState();
}

class MealsComputationScreenState extends State<MealsComputationScreen> {
  List<dynamic>? _records;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  final _amountFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.get('/meal-computations');
      if (!mounted) return;
      setState(() {
        _records = res.data as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.isEmpty) return '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return text;
    final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (isoMatch != null) return isoMatch.group(1)!;
    final date = DateTime.tryParse(text);
    if (date != null) return DateFormat('yyyy-MM-dd').format(date);
    return text;
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '';
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().replaceAll(',', '').replaceAll('₱', ''));
    if (parsed == null) return '';
    return '₱${_amountFormat.format(parsed)}';
  }

  double? _parseAmount(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '').replaceAll('₱', '').trim());
  }

  int? _parseInt(String text) => int.tryParse(text.trim());

  double _num(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _lunchTotal(Map<String, dynamic> m) {
    if (m['lunch_total'] != null) return _num(m, 'lunch_total');
    return _num(m, 'pax') * _num(m, 'days') * _num(m, 'lunch_rate');
  }

  double _snacksTotal(Map<String, dynamic> m) {
    if (m['snacks_total'] != null) return _num(m, 'snacks_total');
    return _num(m, 'pax') * _num(m, 'days') * _num(m, 'snacks_per_day') * _num(m, 'snack_rate');
  }

  double _grandTotal(Map<String, dynamic> m) =>
      _lunchTotal(m) + _snacksTotal(m);

  Future<void> _showForm({Map<String, dynamic>? record}) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: record?['title'] ?? '');
    final venue = TextEditingController(text: record?['venue'] ?? '');
    final dateStart = TextEditingController(text: _formatDate(record?['date_start']));
    final dateEnd = TextEditingController(text: _formatDate(record?['date_end']));
    final pax = TextEditingController(text: record?['pax']?.toString() ?? '');
    final days = TextEditingController(text: record?['days']?.toString() ?? '1');
    final lunchRate = TextEditingController(
        text: record != null ? _num(record, 'lunch_rate').toStringAsFixed(2) : '');
    final snackRate = TextEditingController(
        text: record != null ? _num(record, 'snack_rate').toStringAsFixed(2) : '');
    final snacksPerDay = TextEditingController(
        text: record?['snacks_per_day']?.toString() ?? '2');
    final remarks = TextEditingController(text: record?['remarks'] ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double currentPax() => (_parseInt(pax.text) ?? 0).toDouble();
          double currentDays() => (_parseInt(days.text) ?? 0).toDouble();
          double lunch() => currentPax() * currentDays() * (_parseAmount(lunchRate.text) ?? 0);
          double snacks() => currentPax() * currentDays() *
              (_parseInt(snacksPerDay.text) ?? 0) * (_parseAmount(snackRate.text) ?? 0);

          return AlertDialog(
            title: Text(record == null ? 'Add Meal Computation' : 'Edit Meal Computation'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Activity / Title'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: venue,
                      decoration: const InputDecoration(labelText: 'Venue'),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: dateStart,
                        decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD)'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: dateEnd,
                        decoration: const InputDecoration(labelText: 'End Date (YYYY-MM-DD)'),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: pax,
                        decoration: const InputDecoration(labelText: 'No. of Pax'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (_parseInt(v ?? '') == null) ? 'Required' : null,
                        onChanged: (_) => setDialogState(() {}),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: days,
                        decoration: const InputDecoration(labelText: 'No. of Days'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (_parseInt(v ?? '') ?? 0) < 1 ? 'Required' : null,
                        onChanged: (_) => setDialogState(() {}),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: lunchRate,
                      decoration: const InputDecoration(labelText: 'Lunch Rate (per pax/day)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: snackRate,
                        decoration: const InputDecoration(labelText: 'Snack Rate (per snack)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setDialogState(() {}),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: snacksPerDay,
                        decoration: const InputDecoration(labelText: 'Snacks / Day'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {}),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: remarks,
                      decoration: const InputDecoration(labelText: 'Remarks'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    // Live total preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.csuMaroon.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lunch Total: ${_formatAmount(lunch())}'),
                          Text('Snacks Total: ${_formatAmount(snacks())}'),
                          const SizedBox(height: 4),
                          Text(
                            'Grand Total: ${_formatAmount(lunch() + snacks())}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final payload = <String, dynamic>{
                    'title': title.text.trim(),
                    'venue': venue.text.trim().isEmpty ? null : venue.text.trim(),
                    'date_start': dateStart.text.trim().isEmpty ? null : dateStart.text.trim(),
                    'date_end': dateEnd.text.trim().isEmpty ? null : dateEnd.text.trim(),
                    'pax': _parseInt(pax.text) ?? 0,
                    'days': _parseInt(days.text) ?? 1,
                    'lunch_rate': _parseAmount(lunchRate.text) ?? 0,
                    'snack_rate': _parseAmount(snackRate.text) ?? 0,
                    'snacks_per_day': _parseInt(snacksPerDay.text) ?? 0,
                    'remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim(),
                  };
                  Navigator.pop(context);
                  _save(record?['id'], payload);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(int? id, Map<String, dynamic> payload) async {
    try {
      if (id == null) {
        await ApiClient.post('/meal-computations', data: payload);
      } else {
        await ApiClient.put('/meal-computations/$id', data: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
      load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${record['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/meal-computations/${record['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
      load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _dateRange(Map<String, dynamic> m) {
    final start = _formatDate(m['date_start']);
    final end = _formatDate(m['date_end']);
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty || start == end) return start;
    return '$start - $end';
  }

  (List<String>, List<List<String>>) _buildExportData() {
    final headers = ['Activity / Title', 'Venue', 'Date(s)', 'Pax', 'Days',
        'Lunch Rate', 'Snack Rate', 'Snacks/Day',
        'Lunch Total', 'Snacks Total', 'Grand Total', 'Remarks'];
    final data = (_records ?? []).map((r) {
      final m = r as Map<String, dynamic>;
      return [
        m['title']?.toString() ?? '',
        m['venue']?.toString() ?? '',
        _dateRange(m),
        m['pax']?.toString() ?? '',
        m['days']?.toString() ?? '',
        _formatAmount(m['lunch_rate']),
        _formatAmount(m['snack_rate']),
        m['snacks_per_day']?.toString() ?? '',
        _formatAmount(_lunchTotal(m)),
        _formatAmount(_snacksTotal(m)),
        _formatAmount(_grandTotal(m)),
        m['remarks']?.toString() ?? '',
      ];
    }).toList();
    return (headers, data);
  }

  Future<void> _saveFile(List<int> bytes, {required String fileName, required String extension}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File', fileName: fileName,
        type: FileType.custom, allowedExtensions: [extension]);
      if (outputPath == null) return;
      await File(outputPath).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $outputPath')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], subject: fileName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $fileName')));
    }
  }

  String _exportFileName() =>
      'meals_computation_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (final row in data) {
        sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
      }
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
      String esc(String s) => s.replaceAll(amp, '${amp}amp;')
          .replaceAll('<', '${amp}lt;').replaceAll('>', '${amp}gt;');
      final buf = StringBuffer()
        ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">')
        ..writeln('<head><meta charset="utf-8"><style>body{font-family:Arial;font-size:10pt}table{border-collapse:collapse;width:100%}th,td{border:1px solid #000;padding:4pt}th{background:#d9d9d9;font-weight:bold}</style></head><body>')
        ..writeln('<h2>Lunch &amp; Snacks Computation</h2><table><thead><tr>');
      for (final h in headers) { buf.writeln('<th>${esc(h)}</th>'); }
      buf.writeln('</tr></thead><tbody>');
      for (final row in data) {
        buf.writeln('<tr>');
        for (final c in row) { buf.writeln('<td>${esc(c)}</td>'); }
        buf.writeln('</tr>');
      }
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
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text('Lunch & Snacks Computation',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers, data: data, border: null,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 24, cellStyle: const pw.TextStyle(fontSize: 8),
            headerCellDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ));
      await _saveFile(await pdf.save(), fileName: '${_exportFileName()}.pdf', extension: 'pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: load);

    final list = _records ?? [];
    const columns = [
      DataColumn(label: Text('Activity / Title')),
      DataColumn(label: Text('Venue')),
      DataColumn(label: Text('Date(s)')),
      DataColumn(label: Text('Pax')),
      DataColumn(label: Text('Days')),
      DataColumn(label: Text('Lunch Rate')),
      DataColumn(label: Text('Snack Rate')),
      DataColumn(label: Text('Snacks/Day')),
      DataColumn(label: Text('Lunch Total')),
      DataColumn(label: Text('Snacks Total')),
      DataColumn(label: Text('Grand Total')),
      DataColumn(label: Text('Remarks')),
      DataColumn(label: Text('Actions')),
    ];

    final rows = list.map<DataRow>((r) {
      final m = r as Map<String, dynamic>;
      return DataRow(cells: [
        DataCell(SizedBox(width: 200, child: Text(m['title']?.toString() ?? '', softWrap: true))),
        DataCell(Text(m['venue']?.toString() ?? '')),
        DataCell(Text(_dateRange(m))),
        DataCell(Text(m['pax']?.toString() ?? '')),
        DataCell(Text(m['days']?.toString() ?? '')),
        DataCell(Text(_formatAmount(m['lunch_rate']))),
        DataCell(Text(_formatAmount(m['snack_rate']))),
        DataCell(Text(m['snacks_per_day']?.toString() ?? '')),
        DataCell(Text(_formatAmount(_lunchTotal(m)))),
        DataCell(Text(_formatAmount(_snacksTotal(m)))),
        DataCell(Text(_formatAmount(_grandTotal(m)),
            style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(SizedBox(width: 200, child: Text(m['remarks']?.toString() ?? '', softWrap: true))),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(record: m)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error), onPressed: () => _delete(m)),
        ])),
      ]);
    }).toList();

    final grandTotal = list.fold<double>(
        0, (sum, r) => sum + _grandTotal(r as Map<String, dynamic>));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: load),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Computation'),
              ),
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
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Overall Grand Total: ${_formatAmount(grandTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
            ? const EmptyState(icon: Icons.restaurant_outlined, title: 'No computations yet', subtitle: 'Add a lunch & snacks computation')
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateColor.resolveWith((_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: double.infinity,
                    columns: columns,
                    rows: rows,
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _exportButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.download, size: 18),
        SizedBox(width: 8),
        Text('Export'),
      ]),
    );
  }
}
