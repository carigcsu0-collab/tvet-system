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

/// Day-by-day attendance matrix for a training batch: one row per trainee,
/// one column per session date. Tap a cell to cycle Present -> Half Day ->
/// Absent. Mirrors the "Summary of Attendance" spreadsheet used manually.
class TrainingAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> batch;
  const TrainingAttendanceScreen({super.key, required this.batch});

  @override
  State<TrainingAttendanceScreen> createState() => _TrainingAttendanceScreenState();
}

class _TrainingAttendanceScreenState extends State<TrainingAttendanceScreen> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  List<Map<String, dynamic>> _trainees = [];
  List<String> _dates = [];
  Map<int, Map<String, String>> _records = {};

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
      final res = await ApiClient.get('/training-batches/$_batchId/attendance');
      final data = res.data as Map<String, dynamic>;
      final recordsRaw = (data['records'] as Map<String, dynamic>? ?? {});
      final records = <int, Map<String, String>>{};
      recordsRaw.forEach((traineeId, dateMap) {
        records[int.parse(traineeId)] = Map<String, String>.from(dateMap as Map);
      });
      if (!mounted) return;
      setState(() {
        _trainees = (data['trainees'] as List<dynamic>).cast<Map<String, dynamic>>();
        _dates = (data['dates'] as List<dynamic>).cast<String>();
        _records = records;
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

  Future<void> _addDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(picked);
    try {
      await ApiClient.post('/training-batches/$_batchId/attendance/dates', data: {'date': dateStr});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _removeDate(String date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Date'),
        content: Text('Remove attendance column for $date?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/training-batches/$_batchId/attendance/dates', data: {'date': date});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  static const List<String> _cycle = ['present', 'half_day', 'absent'];

  Future<void> _cycleStatus(int traineeId, String date) async {
    final current = _records[traineeId]?[date] ?? 'present';
    final next = _cycle[(_cycle.indexOf(current) + 1) % _cycle.length];
    setState(() {
      _records.putIfAbsent(traineeId, () => {})[date] = next;
    });
    try {
      await ApiClient.put('/training-batches/$_batchId/attendance/records', data: {
        'assessee_id': traineeId,
        'date': date,
        'status': next,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      _load();
    }
  }

  Future<void> _manageTrainees() async {
    List<dynamic> available = [];
    try {
      final res = await ApiClient.get('/training-batches/$_batchId/available-trainees');
      available = res.data as List<dynamic>;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      return;
    }
    final currentIds = _trainees.map((t) => t['id'] as int).toSet();
    final selected = <int>{...currentIds};

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manage Trainees'),
          content: SizedBox(
            width: 400,
            child: available.isEmpty
                ? const Text('No trainees found for this training center. Add trainees under Training Centers first.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: available.map((t) {
                        final id = t['id'] as int;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t['name']?.toString() ?? ''),
                          value: selected.contains(id),
                          onChanged: (v) => setDialogState(() {
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _applyTraineeSelection(currentIds, selected);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyTraineeSelection(Set<int> before, Set<int> after) async {
    try {
      final toAdd = after.difference(before);
      final toRemove = before.difference(after);
      if (toAdd.isNotEmpty) {
        await ApiClient.post('/training-batches/$_batchId/trainees', data: {'assessee_ids': toAdd.toList()});
      }
      for (final id in toRemove) {
        await ApiClient.delete('/training-batches/$_batchId/trainees/$id');
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // (present count, absent count) for one trainee, half-day counts as 0.5 each way.
  (double, double) _totalsFor(int traineeId) {
    double present = 0;
    for (final date in _dates) {
      final status = _records[traineeId]?[date] ?? 'present';
      if (status == 'present') {
        present += 1;
      } else if (status == 'half_day') {
        present += 0.5;
      }
    }
    final total = _dates.length.toDouble();
    return (present, total - present);
  }

  String _fmtDateHeader(String date) {
    final d = DateTime.tryParse(date);
    return d != null ? DateFormat('MM/dd').format(d) : date;
  }

  String _fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _fmtPct(double v) => '${(v * 100).toStringAsFixed(0)}%';

  Widget _statusCell(int traineeId, String date) {
    final status = _records[traineeId]?[date] ?? 'present';
    late Color color;
    late String label;
    switch (status) {
      case 'present':
        color = AppTheme.success;
        label = 'P';
        break;
      case 'half_day':
        color = AppTheme.warning;
        label = 'H';
        break;
      default:
        color = AppTheme.error;
        label = 'A';
    }
    return InkWell(
      onTap: () => _cycleStatus(traineeId, date),
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        width: 32,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.batch['center'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.batch['qualification'] ?? ''}'),
      ),
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
                          const SizedBox(height: AppTheme.spaceSm),
                          Wrap(
                            spacing: AppTheme.spaceSm,
                            runSpacing: AppTheme.spaceSm,
                            children: [
                              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: _load),
                              OutlinedButton.icon(
                                onPressed: _manageTrainees,
                                icon: const Icon(Icons.people_outline, size: 18),
                                label: const Text('Manage Trainees'),
                              ),
                              FilledButton.icon(
                                onPressed: _addDate,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Date'),
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
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _trainees.isEmpty
                          ? const EmptyState(
                              icon: Icons.people_outline,
                              title: 'No trainees in this batch',
                              subtitle: 'Tap "Manage Trainees" to add trainees from this training center',
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateColor.resolveWith((_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 52,
                                  columns: [
                                    const DataColumn(label: Text('#')),
                                    const DataColumn(label: SizedBox(width: 180, child: Text('Name'))),
                                    for (final date in _dates)
                                      DataColumn(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_fmtDateHeader(date)),
                                            InkWell(
                                              onTap: () => _removeDate(date),
                                              child: const Padding(
                                                padding: EdgeInsets.only(left: 2),
                                                child: Icon(Icons.close, size: 14, color: Colors.grey),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const DataColumn(label: Text('Present %')),
                                    const DataColumn(label: Text('Absent %')),
                                    const DataColumn(label: Text('Present')),
                                    const DataColumn(label: Text('Absent')),
                                  ],
                                  rows: [
                                    for (var i = 0; i < _trainees.length; i++)
                                      DataRow(cells: () {
                                        final t = _trainees[i];
                                        final id = t['id'] as int;
                                        final (present, absent) = _totalsFor(id);
                                        final total = _dates.length.toDouble();
                                        return [
                                          DataCell(Text('${i + 1}')),
                                          DataCell(SizedBox(width: 180, child: Text(t['name']?.toString() ?? '', softWrap: true))),
                                          for (final date in _dates) DataCell(_statusCell(id, date)),
                                          DataCell(Text(total == 0 ? '-' : _fmtPct(present / total))),
                                          DataCell(Text(total == 0 ? '-' : _fmtPct(absent / total))),
                                          DataCell(Text(_fmtNum(present))),
                                          DataCell(Text(_fmtNum(absent))),
                                        ];
                                      }()),
                                  ],
                                ),
                              ),
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
    final headers = ['No', 'Name', for (final d in _dates) _fmtDateHeader(d), 'Present %', 'Absent %', 'Total Present', 'Total Absent'];
    final data = <List<String>>[];
    for (var i = 0; i < _trainees.length; i++) {
      final t = _trainees[i];
      final id = t['id'] as int;
      final (present, absent) = _totalsFor(id);
      final total = _dates.length.toDouble();
      data.add([
        '${i + 1}',
        t['name']?.toString() ?? '',
        for (final date in _dates)
          switch (_records[id]?[date] ?? 'present') {
            'present' => '1',
            'half_day' => '0.5',
            _ => '0',
          },
        total == 0 ? '' : _fmtPct(present / total),
        total == 0 ? '' : _fmtPct(absent / total),
        _fmtNum(present),
        _fmtNum(absent),
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

  String _exportFileName() => 'attendance_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (final row in data) { sheet.appendRow(row.map((c) => TextCellValue(c)).toList()); }
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
      final esc = (String s) => s.replaceAll(amp, '${amp}amp;').replaceAll('<', '${amp}lt;').replaceAll('>', '${amp}gt;');
      final buf = StringBuffer()
        ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">')
        ..writeln('<head><meta charset="utf-8"><style>body{font-family:Arial;font-size:9pt}table{border-collapse:collapse;width:100%}th,td{border:1px solid #000;padding:3pt;text-align:center}th{background:#d9d9d9;font-weight:bold}</style></head><body>')
        ..writeln('<h3>Summary of Attendance - ${widget.batch['qualification'] ?? ''}</h3><table><thead><tr>');
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
          pw.Text('Summary of Attendance - ${widget.batch['qualification'] ?? ''}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers, data: data, border: null,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 20, cellStyle: const pw.TextStyle(fontSize: 7),
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
