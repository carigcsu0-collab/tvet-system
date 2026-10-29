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

/// TESDA billing monitoring: one row per billing with the date billed,
/// qualification, amount, number of pax, payment status and date.
class TesdaBillingScreen extends StatefulWidget {
  const TesdaBillingScreen({super.key});

  @override
  State<TesdaBillingScreen> createState() => TesdaBillingScreenState();
}

class TesdaBillingScreenState extends State<TesdaBillingScreen> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _centers = [];
  String _search = '';
  String _statusFilter = 'all';
  DateTimeRange? _dateRange;

  static const _exportHeaders = [
    'No',
    'Date of Billing',
    'Center',
    'Qualifications',
    'Amount (Php)',
    'Pax',
    'Status',
    'Date',
    'Received Date',
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.get('/tesda-billings'),
        ApiClient.get('/centers'),
      ]);
      if (!mounted) return;
      setState(() {
        _records = (results[0].data as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _centers = (results[1].data as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length < 10) return null;
    return DateTime.tryParse(text.substring(0, 10));
  }

  String? _isoDate(DateTime? date) => date == null ? null : DateFormat('yyyy-MM-dd').format(date);

  String _displayDate(dynamic value) => _isoDate(_parseDate(value)) ?? '';

  double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  String _money(double value) {
    final peso = String.fromCharCode(8369);
    return '$peso${NumberFormat('#,##0.00', 'en_US').format(value)}';
  }

  String _plainMoney(double value) => NumberFormat('#,##0.00', 'en_US').format(value);

  String _statusLabel(String status) => status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1);

  StatusBadgeType _statusType(String status) {
    switch (status) {
      case 'paid':
        return StatusBadgeType.success;
      case 'cancelled':
        return StatusBadgeType.error;
      default:
        return StatusBadgeType.warning;
    }
  }

  List<Map<String, dynamic>> _centersOfType(String type) =>
      _centers.where((c) => c['type']?.toString() == type).toList();

  /// Qualifications offered by the saved center, used to fill the form.
  List<String> _qualificationsOf(int? centerId) {
    if (centerId == null) return [];
    final match = _centers.where((c) => c['id'] == centerId);
    if (match.isEmpty) return [];
    return (match.first['qualifications'] as List<dynamic>? ?? [])
        .map((q) => q.toString().trim())
        .where((q) => q.isNotEmpty)
        .toList();
  }

  String _centerLabel(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? '';
    final address = c['address']?.toString() ?? '';
    return address.isEmpty ? name : '$name - $address';
  }

  String _typeLabel(String? type) => type == 'training' ? 'Training' : 'Assessment';

  String _centerText(Map<String, dynamic> r) {
    final center = r['center'];
    final name = center is Map ? center['name']?.toString() ?? '' : '';
    if (name.isEmpty) return '-';
    return '${_typeLabel(r['center_type']?.toString())}: $name';
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _search.trim().toLowerCase();
    return _records.where((r) {
      if (_statusFilter != 'all' && r['status'] != _statusFilter) return false;
      if (query.isNotEmpty) {
        final haystack = '${r['qualification'] ?? ''} ${_centerText(r)}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      if (_dateRange != null) {
        final date = _parseDate(r['billing_date']);
        if (date == null || date.isBefore(_dateRange!.start) || date.isAfter(_dateRange!.end)) return false;
      }
      return true;
    }).toList();
  }

  double get _totalAmount => _filtered.fold(0, (sum, r) => sum + _num(r['amount']));

  int get _totalPax => _filtered.fold(0, (sum, r) => sum + _num(r['pax']).round());

  double _amountWithStatus(String status) =>
      _filtered.where((r) => r['status'] == status).fold(0, (sum, r) => sum + _num(r['amount']));

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Widget _datePicker(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool clearable = false,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: clearable && value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear',
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value == null ? '' : DateFormat('yyyy-MM-dd').format(value)),
      ),
    );
  }

  Future<void> _showForm({Map<String, dynamic>? record}) async {
    final formKey = GlobalKey<FormState>();
    DateTime billingDate = _parseDate(record?['billing_date']) ?? DateTime.now();
    DateTime? recordDate = _parseDate(record?['record_date']);
    DateTime? receivedDate = _parseDate(record?['received_date']);
    String status = record?['status']?.toString() ?? 'pending';
    String centerType = record?['center_type']?.toString() ?? 'assessment';
    int? centerId = (record?['center_id'] as num?)?.toInt();
    if (!_centersOfType(centerType).any((c) => c['id'] == centerId)) centerId = null;
    String? qualification = record?['qualification']?.toString();
    if (!_qualificationsOf(centerId).contains(qualification)) qualification = null;
    final amount = TextEditingController(text: record == null ? '' : _num(record['amount']).toStringAsFixed(2));
    final pax = TextEditingController(text: record?['pax']?.toString() ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add TESDA Billing' : 'Edit TESDA Billing'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _datePicker(
                      context,
                      label: 'Date of Billing',
                      value: billingDate,
                      onChanged: (d) {
                        if (d != null) setDialogState(() => billingDate = d);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: centerType,
                      decoration: const InputDecoration(labelText: 'Center Type'),
                      items: const [
                        DropdownMenuItem(value: 'assessment', child: Text('Assessment Center')),
                        DropdownMenuItem(value: 'training', child: Text('Training Center')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          centerType = v;
                          centerId = null;
                          qualification = null;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: ValueKey('center-$centerType'),
                      initialValue: centerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Center',
                        helperText: _centersOfType(centerType).isEmpty ? 'No saved centers of this type' : null,
                      ),
                      items: [
                        for (final c in _centersOfType(centerType))
                          DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(_centerLabel(c), overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      validator: (v) => v == null ? 'Select a center' : null,
                      onChanged: (v) => setDialogState(() {
                        centerId = v;
                        qualification = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('qual-$centerId'),
                      initialValue: qualification,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Qualifications',
                        helperText: centerId == null
                            ? 'Select a center first'
                            : (_qualificationsOf(centerId).isEmpty ? 'This center has no qualifications' : null),
                      ),
                      items: [
                        for (final q in _qualificationsOf(centerId))
                          DropdownMenuItem(value: q, child: Text(q)),
                      ],
                      validator: (v) => v == null ? 'Select a qualification' : null,
                      onChanged: (v) => setDialogState(() => qualification = v),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (Php)'),
                      validator: (v) {
                        final value = double.tryParse((v ?? '').replaceAll(',', '').trim());
                        return value == null || value < 0 ? 'Enter a valid amount' : null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: pax,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pax'),
                      validator: (v) {
                        final value = int.tryParse((v ?? '').trim());
                        return value == null || value < 0 ? 'Enter a valid number' : null;
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in const ['pending', 'paid', 'cancelled'])
                          DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => status = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    _datePicker(
                      context,
                      label: 'Date (optional)',
                      value: recordDate,
                      clearable: true,
                      onChanged: (d) => setDialogState(() => recordDate = d),
                    ),
                    const SizedBox(height: 8),
                    _datePicker(
                      context,
                      label: 'Received Date (optional)',
                      value: receivedDate,
                      clearable: true,
                      onChanged: (d) => setDialogState(() => receivedDate = d),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final payload = <String, dynamic>{
                  'billing_date': _isoDate(billingDate),
                  'center_id': centerId,
                  'qualification': qualification ?? '',
                  'amount': double.parse(amount.text.replaceAll(',', '').trim()),
                  'pax': int.parse(pax.text.trim()),
                  'status': status,
                  'record_date': _isoDate(recordDate),
                  'received_date': _isoDate(receivedDate),
                };
                Navigator.pop(dialogContext);
                _save(record?['id'], payload);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(dynamic id, Map<String, dynamic> payload) async {
    try {
      if (id == null) {
        await ApiClient.post('/tesda-billings', data: payload);
      } else {
        await ApiClient.put('/tesda-billings/$id', data: payload);
      }
      _showMessage('Saved');
      await load();
    } catch (e) {
      _showMessage('Save failed: $e');
    }
  }

  /// Status workflow: quick transition that keeps every other field intact.
  Future<void> _setStatus(Map<String, dynamic> r, String status) async {
    final payload = <String, dynamic>{
      'billing_date': _displayDate(r['billing_date']),
      'center_id': r['center_id'],
      'qualification': r['qualification']?.toString() ?? '',
      'amount': _num(r['amount']),
      'pax': _num(r['pax']).round(),
      'status': status,
      'record_date': _isoDate(_parseDate(r['record_date'])),
      'received_date': _isoDate(_parseDate(r['received_date'])),
    };
    await _save(r['id'], payload);
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete billing record?'),
        content: Text(r['qualification']?.toString() ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/tesda-billings/${r['id']}');
      _showMessage('Deleted');
      await load();
    } catch (e) {
      _showMessage('Delete failed: $e');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<List<String>> _exportRows(List<Map<String, dynamic>> rows) {
    return [
      for (var i = 0; i < rows.length; i++)
        [
          '${i + 1}',
          _displayDate(rows[i]['billing_date']),
          _centerText(rows[i]),
          rows[i]['qualification']?.toString() ?? '',
          _plainMoney(_num(rows[i]['amount'])),
          '${_num(rows[i]['pax']).round()}',
          _statusLabel(rows[i]['status']?.toString() ?? ''),
          _displayDate(rows[i]['record_date']),
          _displayDate(rows[i]['received_date']),
        ],
    ];
  }

  Future<void> _saveFile(List<int> bytes, {required String fileName, required String extension}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [extension],
      );
      if (outputPath == null) return;
      await File(outputPath).writeAsBytes(bytes);
      _showMessage('Saved to: $outputPath');
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], subject: fileName);
    _showMessage('Exported: $fileName');
  }

  String _exportFileName() => 'tesda_billing_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final rows = _filtered;
      final data = _exportRows(rows);
      final totalRow = ['', '', '', 'TOTAL', _plainMoney(_totalAmount), '$_totalPax', '', '', ''];
      if (format == 'excel') {
        final excel = Excel.createExcel();
        final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
        sheet.appendRow(_exportHeaders.map((h) => TextCellValue(h)).toList());
        for (final row in data) {
          sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
        }
        sheet.appendRow(totalRow.map((c) => TextCellValue(c)).toList());
        final bytes = excel.encode();
        if (bytes == null) throw Exception('Failed to encode');
        await _saveFile(bytes, fileName: '${_exportFileName()}.xlsx', extension: 'xlsx');
      } else {
        final pdf = pw.Document();
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text('TESDA Billing Monitoring', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: _exportHeaders,
              data: [...data, totalRow],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 22,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerCellDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ));
        await _saveFile(await pdf.save(), fileName: '${_exportFileName()}.pdf', extension: 'pdf');
      }
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: load);

    final rows = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search qualification or center',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_dateRange == null
                    ? 'Date range'
                    : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} to ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}'),
                onPressed: _pickDateRange,
              ),
              if (_dateRange != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear date range',
                  onPressed: () => setState(() => _dateRange = null),
                ),
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: load),
              if (_exporting)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'Export',
                  onSelected: _export,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'excel', child: ListTile(leading: Icon(Icons.table_view, size: 20), title: Text('Excel (.xlsx)'), dense: true, contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf, size: 20), title: Text('PDF (.pdf)'), dense: true, contentPadding: EdgeInsets.zero)),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Export')]),
                  ),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () => _showForm(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              _SummaryCard(label: 'Total Amount', value: _money(_totalAmount), color: AppTheme.csuMaroon),
              _SummaryCard(label: 'Paid', value: _money(_amountWithStatus('paid')), color: AppTheme.success),
              _SummaryCard(label: 'Pending', value: _money(_amountWithStatus('pending')), color: AppTheme.warning),
              _SummaryCard(label: 'Total Pax', value: '$_totalPax', color: AppTheme.info),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: _records.isEmpty ? 'No TESDA billing records' : 'No matching records',
                  subtitle: _records.isEmpty ? 'Click Add to create the first billing record' : 'Try changing the search or filters',
                )
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateColor.resolveWith((_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                      columns: const [
                        DataColumn(label: Text('No')),
                        DataColumn(label: Text('Date of Billing')),
                        DataColumn(label: Text('Center')),
                        DataColumn(label: Text('Qualifications')),
                        DataColumn(label: Text('Amount'), numeric: true),
                        DataColumn(label: Text('Pax'), numeric: true),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Received Date')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (var i = 0; i < rows.length; i++)
                          DataRow(cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(_displayDate(rows[i]['billing_date']))),
                            DataCell(Text(_centerText(rows[i]))),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(rows[i]['qualification']?.toString() ?? '', softWrap: true),
                            )),
                            DataCell(Text(_money(_num(rows[i]['amount'])))),
                            DataCell(Text('${_num(rows[i]['pax']).round()}')),
                            DataCell(StatusBadge(
                              label: _statusLabel(rows[i]['status']?.toString() ?? ''),
                              type: _statusType(rows[i]['status']?.toString() ?? ''),
                            )),
                            DataCell(Text(_displayDate(rows[i]['record_date']))),
                            DataCell(Text(_displayDate(rows[i]['received_date']))),
                            DataCell(PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (v) {
                                if (v == 'edit') _showForm(record: rows[i]);
                                if (v == 'delete') _delete(rows[i]);
                                if (v == 'paid' || v == 'pending' || v == 'cancelled') _setStatus(rows[i], v);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                for (final s in _statuses)
                                  if (s != rows[i]['status'])
                                    PopupMenuItem(value: s, child: Text('Mark as ${_statusLabel(s)}')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.error))),
                              ],
                            )),
                          ]),
                        DataRow(cells: [
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(_money(_totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.csuMaroon))),
                          DataCell(Text('$_totalPax', style: const TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                        ]),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

const _statuses = ['pending', 'paid', 'cancelled'];

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
