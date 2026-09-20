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

/// Lunch & Snacks computation.
///
/// Each document (e.g. a 6-day training) holds:
///  - funds: money transactions (cash advances). When money runs out a new
///    fund is added and the remaining balance draws from the combined pool.
///  - items: per-day receipt lines (meal name, quantity, unit price).
/// Totals: per-day subtotal, overall spent, total funds, remaining balance.
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

  // ---------- shared helpers ----------

  static String formatDate(dynamic value) {
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

  static double numVal(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String formatAmount(dynamic value) {
    if (value == null) return '';
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().replaceAll(',', '').replaceAll('₱', ''));
    if (parsed == null) return '';
    return '₱${NumberFormat('#,##0.00', 'en_US').format(parsed)}';
  }

  static double? parseAmount(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '').replaceAll('₱', '').trim());
  }

  static Future<void> saveFile(BuildContext context, List<int> bytes,
      {required String fileName, required String extension}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File', fileName: fileName,
        type: FileType.custom, allowedExtensions: [extension]);
      if (outputPath == null) return;
      await File(outputPath).writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $outputPath')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], subject: fileName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $fileName')));
    }
  }

  // ---------- list logic ----------

  String _dateRange(Map<String, dynamic> m) {
    final start = formatDate(m['date_start']);
    final end = formatDate(m['date_end']);
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty || start == end) return start;
    return '$start - $end';
  }

  Future<void> _showHeaderForm({Map<String, dynamic>? record}) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: record?['title'] ?? '');
    final venue = TextEditingController(text: record?['venue'] ?? '');
    final dateStart = TextEditingController(text: formatDate(record?['date_start']));
    final dateEnd = TextEditingController(text: formatDate(record?['date_end']));
    final days = TextEditingController(text: record?['days']?.toString() ?? '');
    final remarks = TextEditingController(text: record?['remarks'] ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
                TextFormField(
                  controller: days,
                  decoration: const InputDecoration(labelText: 'No. of Days'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: remarks,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
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
                'days': int.tryParse(days.text.trim()),
                'remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim(),
              };
              Navigator.pop(context);
              _save(record?['id'], payload);
            },
            child: const Text('Save'),
          ),
        ],
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
        content: Text('Delete "${record['title']}"? Its funds and items will also be deleted.'),
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

  Future<void> _openDetail(Map<String, dynamic> record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealDocumentDetailPage(documentId: record['id'] as int),
      ),
    );
    load();
  }

  (List<String>, List<List<String>>) _buildExportData() {
    final headers = ['Activity / Title', 'Venue', 'Date(s)', 'Days',
        'Total Funds', 'Total Spent', 'Remaining', 'Remarks'];
    final data = (_records ?? []).map((r) {
      final m = r as Map<String, dynamic>;
      return [
        m['title']?.toString() ?? '',
        m['venue']?.toString() ?? '',
        _dateRange(m),
        m['days']?.toString() ?? '',
        formatAmount(m['funds_total']),
        formatAmount(m['spent_total']),
        formatAmount(m['remaining_balance']),
        m['remarks']?.toString() ?? '',
      ];
    }).toList();
    return (headers, data);
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
      await saveFile(context, bytes, fileName: '${_exportFileName()}.xlsx', extension: 'xlsx');
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
      await saveFile(context, utf8.encode(buf.toString()),
          fileName: '${_exportFileName()}.doc', extension: 'doc');
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
      final bytes = await pdf.save();
      if (!mounted) return;
      await saveFile(context, bytes,
          fileName: '${_exportFileName()}.pdf', extension: 'pdf');
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
      DataColumn(label: Text('Days')),
      DataColumn(label: Text('Total Funds')),
      DataColumn(label: Text('Total Spent')),
      DataColumn(label: Text('Remaining')),
      DataColumn(label: Text('Remarks')),
      DataColumn(label: Text('Actions')),
    ];

    final rows = list.map<DataRow>((r) {
      final m = r as Map<String, dynamic>;
      final remaining = numVal(m, 'remaining_balance');
      return DataRow(cells: [
        DataCell(SizedBox(width: 200, child: Text(m['title']?.toString() ?? '', softWrap: true))),
        DataCell(Text(m['venue']?.toString() ?? '')),
        DataCell(Text(_dateRange(m))),
        DataCell(Text(m['days']?.toString() ?? '')),
        DataCell(Text(formatAmount(m['funds_total']))),
        DataCell(Text(formatAmount(m['spent_total']))),
        DataCell(Text(formatAmount(remaining),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: remaining < 0 ? AppTheme.error : null))),
        DataCell(SizedBox(width: 180, child: Text(m['remarks']?.toString() ?? '', softWrap: true))),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              tooltip: 'Open worksheet',
              onPressed: () => _openDetail(m)),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showHeaderForm(record: m)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error), onPressed: () => _delete(m)),
        ])),
      ]);
    }).toList();

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
                onPressed: () => _showHeaderForm(),
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
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
            ? const EmptyState(icon: Icons.restaurant_outlined, title: 'No computations yet', subtitle: 'Add a meal computation document')
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

// ============================================================
// Detail worksheet: funds (money transactions) + per-day items
// ============================================================

const List<String> _mealOptions = ['AM Snack', 'Lunch', 'PM Snack', 'Dinner', 'Other'];

class _FundRow {
  final label = TextEditingController();
  final date = TextEditingController();
  final amount = TextEditingController();
}

class _ItemRow {
  String name = 'Lunch';
  final customName = TextEditingController();
  final qty = TextEditingController();
  final price = TextEditingController();
}

class _DayGroup {
  final date = TextEditingController();
  final List<_ItemRow> items = [];
}

class MealDocumentDetailPage extends StatefulWidget {
  final int documentId;
  const MealDocumentDetailPage({super.key, required this.documentId});

  @override
  State<MealDocumentDetailPage> createState() => _MealDocumentDetailPageState();
}

class _MealDocumentDetailPageState extends State<MealDocumentDetailPage> {
  Map<String, dynamic>? _doc;
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _exporting = false;

  final List<_FundRow> _funds = [];
  final List<_DayGroup> _days = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.get('/meal-computations/${widget.documentId}');
      if (!mounted) return;
      _doc = res.data as Map<String, dynamic>;
      _populate();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _populate() {
    _funds.clear();
    _days.clear();

    for (final f in (_doc?['funds'] as List? ?? [])) {
      final row = _FundRow();
      row.label.text = f['label']?.toString() ?? '';
      row.date.text = MealsComputationScreenState.formatDate(f['received_date']);
      row.amount.text = MealsComputationScreenState.numVal(
          {'v': f['amount']}, 'v').toStringAsFixed(2);
      _funds.add(row);
    }

    // Group items by item_date into day cards, in order
    final byDate = <String, _DayGroup>{};
    for (final it in (_doc?['items'] as List? ?? [])) {
      final dateStr = MealsComputationScreenState.formatDate(it['item_date']);
      final day = byDate.putIfAbsent(dateStr, () {
        final g = _DayGroup();
        g.date.text = dateStr;
        return g;
      });
      final row = _ItemRow();
      final name = it['name']?.toString() ?? 'Lunch';
      if (_mealOptions.contains(name)) {
        row.name = name;
      } else {
        row.name = 'Other';
        row.customName.text = name;
      }
      row.qty.text = MealsComputationScreenState.numVal({'v': it['quantity']}, 'v')
          .toStringAsFixed(0);
      row.price.text = MealsComputationScreenState.numVal({'v': it['unit_price']}, 'v')
          .toStringAsFixed(2);
      day.items.add(row);
    }
    _days.addAll(byDate.values);
  }

  double get _fundsTotal => _funds.fold(0.0,
      (s, f) => s + (MealsComputationScreenState.parseAmount(f.amount.text) ?? 0));

  double _itemTotal(_ItemRow i) =>
      (double.tryParse(i.qty.text.trim()) ?? 0) *
      (MealsComputationScreenState.parseAmount(i.price.text) ?? 0);

  double _dayTotal(_DayGroup d) => d.items.fold(0.0, (s, i) => s + _itemTotal(i));

  double get _spentTotal => _days.fold(0.0, (s, d) => s + _dayTotal(d));

  double get _remaining => _fundsTotal - _spentTotal;

  void _addFund() => setState(() {
        final f = _FundRow();
        f.label.text = 'Cash Advance ${_funds.length + 1}';
        f.date.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _funds.add(f);
      });

  void _addDay() => setState(() {
        final d = _DayGroup();
        // Default to the day after the last day, else date_start, else today
        String next = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final lastDate = _days.isNotEmpty
            ? DateTime.tryParse(_days.last.date.text)
            : DateTime.tryParse(MealsComputationScreenState.formatDate(_doc?['date_start']));
        if (lastDate != null) {
          next = DateFormat('yyyy-MM-dd').format(lastDate.add(const Duration(days: 1)));
        }
        d.date.text = next;
        d.items.add(_ItemRow());
        _days.add(d);
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final funds = _funds.map((f) => {
            'label': f.label.text.trim(),
            'amount': MealsComputationScreenState.parseAmount(f.amount.text) ?? 0,
            'received_date': f.date.text.trim().isEmpty ? null : f.date.text.trim(),
          }).toList();
      final items = <Map<String, dynamic>>[];
      for (final day in _days) {
        for (final item in day.items) {
          final name = item.name == 'Other'
              ? item.customName.text.trim()
              : item.name;
          if (name.isEmpty) continue;
          items.add({
            'item_date': day.date.text.trim().isEmpty ? null : day.date.text.trim(),
            'name': name,
            'quantity': double.tryParse(item.qty.text.trim()) ?? 0,
            'unit_price': MealsComputationScreenState.parseAmount(item.price.text) ?? 0,
          });
        }
      }
      final res = await ApiClient.put(
        '/meal-computations/${widget.documentId}/detail',
        data: {'funds': funds, 'items': items},
      );
      if (!mounted) return;
      _doc = res.data as Map<String, dynamic>;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Worksheet saved')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- per-document export ----------

  List<List<String>> _ledgerRows() {
    final rows = <List<String>>[];
    for (final day in _days) {
      for (final item in day.items) {
        final name = item.name == 'Other' ? item.customName.text.trim() : item.name;
        rows.add([
          day.date.text,
          name,
          item.qty.text,
          item.price.text,
          _itemTotal(item).toStringAsFixed(2),
        ]);
      }
      rows.add(['', 'Day Total (${day.date.text})', '', '', _dayTotal(day).toStringAsFixed(2)]);
    }
    return rows;
  }

  String _detailFileName() =>
      'meals_${widget.documentId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

  Future<void> _exportDetailPdf() async {
    setState(() => _exporting = true);
    try {
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(_doc?['title']?.toString() ?? 'Meal Computation',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Venue: ${_doc?['venue'] ?? ''}   '
              'Dates: ${MealsComputationScreenState.formatDate(_doc?['date_start'])} - '
              '${MealsComputationScreenState.formatDate(_doc?['date_end'])}'),
          pw.SizedBox(height: 12),
          pw.Text('Funds', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Fund', 'Date', 'Amount'],
            data: _funds.map((f) => [f.label.text, f.date.text, f.amount.text]).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Meal Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Item', 'Qty', 'Unit Price', 'Total'],
            data: _ledgerRows(),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total Funds: ${MealsComputationScreenState.formatAmount(_fundsTotal)}'),
          pw.Text('Total Spent: ${MealsComputationScreenState.formatAmount(_spentTotal)}'),
          pw.Text('Remaining Balance: ${MealsComputationScreenState.formatAmount(_remaining)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ));
      final bytes = await doc.save();
      if (!mounted) return;
      await MealsComputationScreenState.saveFile(context, bytes,
          fileName: '${_detailFileName()}.pdf', extension: 'pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  Future<void> _exportDetailExcel() async {
    setState(() => _exporting = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      sheet.appendRow([TextCellValue(_doc?['title']?.toString() ?? 'Meal Computation')]);
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('Fund'), TextCellValue('Date'), TextCellValue('Amount')]);
      for (final f in _funds) {
        sheet.appendRow([TextCellValue(f.label.text), TextCellValue(f.date.text), TextCellValue(f.amount.text)]);
      }
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('Date'), TextCellValue('Item'), TextCellValue('Qty'),
          TextCellValue('Unit Price'), TextCellValue('Total')]);
      for (final row in _ledgerRows()) {
        sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
      }
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('Total Funds'), TextCellValue(_fundsTotal.toStringAsFixed(2))]);
      sheet.appendRow([TextCellValue('Total Spent'), TextCellValue(_spentTotal.toStringAsFixed(2))]);
      sheet.appendRow([TextCellValue('Remaining Balance'), TextCellValue(_remaining.toStringAsFixed(2))]);
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode');
      await MealsComputationScreenState.saveFile(context, bytes,
          fileName: '${_detailFileName()}.xlsx', extension: 'xlsx');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc?['title']?.toString() ?? 'Meal Computation'),
        actions: [
          if (_exporting)
            const Padding(padding: EdgeInsets.all(14), child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            IconButton(
                icon: const Icon(Icons.table_view),
                tooltip: 'Export Excel',
                onPressed: _exportDetailExcel),
            IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Export PDF',
                onPressed: _exportDetailPdf),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        label: const Text('Save'),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary strip
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _summaryChip('Total Funds', _fundsTotal, AppTheme.success),
              _summaryChip('Total Spent', _spentTotal, AppTheme.warning),
              _summaryChip('Remaining', _remaining,
                  _remaining < 0 ? AppTheme.error : AppTheme.info),
            ],
          ),
          if (_remaining < 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Funds exhausted — add a new money transaction below; spending will draw from the new amount.',
                style: TextStyle(color: isDark ? Colors.red.shade300 : AppTheme.error),
              ),
            ),
          const SizedBox(height: 20),

          // Funds (money transactions)
          Row(children: [
            const Text('Money Transactions (Funds)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addFund,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Fund'),
            ),
          ]),
          const SizedBox(height: 8),
          if (_funds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No funds yet — add the money allocated for this activity.'),
            )
          else
            ...List.generate(_funds.length, (i) => _fundRow(i)),
          const SizedBox(height: 24),

          // Daily expenses
          Row(children: [
            const Text('Daily Meal Expenses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addDay,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Day'),
            ),
          ]),
          const SizedBox(height: 8),
          if (_days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No days yet — add a day, then add meal items (snacks, lunch, dinner).'),
            )
          else
            ...List.generate(_days.length, (i) => _dayCard(i)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          Text(MealsComputationScreenState.formatAmount(value),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        ],
      ),
    );
  }

  Widget _fundRow(int i) {
    final f = _funds[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: f.label,
            decoration: const InputDecoration(labelText: 'Label', isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: f.date,
            decoration: const InputDecoration(labelText: 'Date', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: f.amount,
            decoration: const InputDecoration(labelText: 'Amount (₱)', isDense: true),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.error),
          onPressed: () => setState(() => _funds.removeAt(i)),
        ),
      ]),
    );
  }

  Widget _dayCard(int i) {
    final day = _days[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Day ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TextFormField(
                  controller: day.date,
                  decoration: const InputDecoration(labelText: 'Date', isDense: true),
                ),
              ),
              const Spacer(),
              Text('Day Total: ${MealsComputationScreenState.formatAmount(_dayTotal(day))}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                tooltip: 'Remove day',
                onPressed: () => setState(() => _days.removeAt(i)),
              ),
            ]),
            const Divider(),
            ...List.generate(day.items.length, (j) => _itemRow(day, j)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => day.items.add(_ItemRow())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(_DayGroup day, int j) {
    final item = day.items[j];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<String>(
            initialValue: item.name,
            decoration: const InputDecoration(labelText: 'Meal', isDense: true),
            items: _mealOptions
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => item.name = v ?? 'Lunch'),
          ),
        ),
        if (item.name == 'Other') ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: item.customName,
              decoration: const InputDecoration(labelText: 'Item name', isDense: true),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: item.qty,
            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: item.price,
            decoration: const InputDecoration(labelText: 'Unit Price', isDense: true),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(MealsComputationScreenState.formatAmount(_itemTotal(item)),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppTheme.error),
          onPressed: () => setState(() => day.items.removeAt(j)),
        ),
      ]),
    );
  }
}
