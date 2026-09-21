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

/// Document monitoring screen with 4 tabs:
/// Internal Communication, External Communication, Purchase Request, Reimbursement.
/// Each tab tracks documents through their lifecycle with status updates and export.
class DocumentMonitoringScreen extends StatefulWidget {
  const DocumentMonitoringScreen({super.key});

  @override
  State<DocumentMonitoringScreen> createState() =>
      _DocumentMonitoringScreenState();
}

class _DocumentMonitoringScreenState extends State<DocumentMonitoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Communication status options (combined A + B)
  static const List<String> _commStatuses = [
    'Pending',
    'Saved',
    'Received',
    'Forwarded',
    'Filed',
  ];

  // PR / Reimbursement status options (combined A + B)
  static const List<String> _prStatuses = [
    'Pending',
    'Processing',
    'Approved',
    'Released',
    'Received',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.mail_outlined), text: 'Internal'),
            Tab(icon: Icon(Icons.forward_to_inbox_outlined), text: 'External'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Purchase Request'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Reimbursement'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _CommunicationTab(type: 'internal', statuses: _commStatuses),
              _CommunicationTab(type: 'external', statuses: _commStatuses),
              _PurchaseRequestTab(statuses: _prStatuses),
              _ReimbursementTab(statuses: _prStatuses),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Communication Tab (Internal & External share the same layout)
// ============================================================
class _CommunicationTab extends StatefulWidget {
  final String type;
  final List<String> statuses;

  const _CommunicationTab({required this.type, required this.statuses});

  @override
  State<_CommunicationTab> createState() => _CommunicationTabState();
}

class _CommunicationTabState extends State<_CommunicationTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _records;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.get('/communications?type=${widget.type}');
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

  String get _title => widget.type == 'internal'
      ? 'Internal Communications'
      : 'External Communications';

  Future<void> _showForm({Map<String, dynamic>? record}) async {
    final formKey = GlobalKey<FormState>();
    final documentCode = TextEditingController(text: record?['document_code'] ?? '');
    final documentTitle = TextEditingController(text: record?['document_title'] ?? '');
    final date = TextEditingController(text: _formatDate(record?['date']));
    final officeReceived = TextEditingController(text: record?['office_received'] ?? '');
    final receivedDate = TextEditingController(text: _formatDate(record?['received_date']));
    final remarks = TextEditingController(text: record?['remarks'] ?? '');
    String status = record?['status'] ?? 'Pending';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add $_title' : 'Edit $_title'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: documentCode,
                    decoration: const InputDecoration(labelText: 'Document Code'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: documentTitle,
                    decoration: const InputDecoration(labelText: 'Document Title'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: date,
                    decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: widget.statuses.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDialogState(() => status = v ?? 'Pending'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: officeReceived,
                    decoration: const InputDecoration(labelText: 'Office Received'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: receivedDate,
                    decoration: const InputDecoration(labelText: 'Received Date (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: remarks,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final payload = <String, dynamic>{
                  'type': widget.type,
                  'document_code': documentCode.text.trim(),
                  'document_title': documentTitle.text.trim(),
                  'date': date.text.trim().isEmpty ? null : date.text.trim(),
                  'status': status,
                  'office_received': officeReceived.text.trim(),
                  'received_date': receivedDate.text.trim().isEmpty ? null : receivedDate.text.trim(),
                  'remarks': remarks.text.trim(),
                };
                Navigator.pop(context);
                _save(record?['id'], payload);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(int? id, Map<String, dynamic> payload) async {
    try {
      if (id == null) {
        await ApiClient.post('/communications', data: payload);
      } else {
        await ApiClient.put('/communications/$id', data: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
      _load();
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
        content: Text('Delete "${record['document_title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/communications/${record['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.isEmpty) return '';
    // If it's already a plain Y-m-d string, return as-is (no timezone shift)
    final plainDateMatch = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(text);
    if (plainDateMatch != null) return text;
    // For ISO8601 strings (e.g. 2026-09-16T16:00:00.000000Z), parse and
    // format using the date portion directly to avoid UTC-to-local shift
    final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (isoMatch != null) return isoMatch.group(1)!;
    final date = DateTime.tryParse(text);
    if (date != null) return DateFormat('yyyy-MM-dd').format(date);
    return text;
  }

  (List<String>, List<List<String>>) _buildExportData() {
    final headers = ['Document Code', 'Document Title', 'Date', 'Status',
        'Office Received', 'Received Date', 'Remarks'];
    final data = (_records ?? []).map((r) {
      final m = r as Map<String, dynamic>;
      return [
        m['document_code']?.toString() ?? '',
        m['document_title']?.toString() ?? '',
        _formatDate(m['date']),
        m['status']?.toString() ?? '',
        m['office_received']?.toString() ?? '',
        _formatDate(m['received_date']),
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

  String _exportFileName() {
    final type = widget.type == 'internal' ? 'internal_comm' : 'external_comm';
    return '${type}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
  }

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
        ..writeln('<h2>$_title</h2><table><thead><tr>');
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(_title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
    super.build(context);
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final list = _records ?? [];
    const columns = [
      DataColumn(label: Text('Doc Code')),
      DataColumn(label: Text('Title')),
      DataColumn(label: Text('Date')),
      DataColumn(label: Text('Status')),
      DataColumn(label: Text('Office Received')),
      DataColumn(label: Text('Received Date')),
      DataColumn(label: Text('Remarks')),
      DataColumn(label: Text('Actions')),
    ];

    final rows = list.map<DataRow>((r) {
      final m = r as Map<String, dynamic>;
      return DataRow(cells: [
        DataCell(Text(m['document_code']?.toString() ?? '')),
        DataCell(SizedBox(width: 220, child: Text(m['document_title']?.toString() ?? '', softWrap: true))),
        DataCell(Text(_formatDate(m['date']))),
        DataCell(_statusBadge(m['status']?.toString() ?? '')),
        DataCell(Text(m['office_received']?.toString() ?? '')),
        DataCell(Text(_formatDate(m['received_date']))),
        DataCell(SizedBox(width: 220, child: Text(m['remarks']?.toString() ?? '', softWrap: true))),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(record: m)),
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
            children: [
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: _load),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add ${widget.type == 'internal' ? 'Internal' : 'External'}'),
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
            ? const EmptyState(icon: Icons.mail_outline, title: 'No records yet', subtitle: 'Add a document to start tracking')
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

  Widget _statusBadge(String status) {
    if (status == 'Received' || status == 'Filed' || status == 'Completed') {
      return StatusBadge.success(status);
    } else if (status == 'Pending' || status == 'Saved') {
      return StatusBadge.warning(status);
    } else if (status == 'Forwarded' || status == 'Processing') {
      return StatusBadge.info(status);
    }
    return Text(status);
  }
}

// ============================================================
// Purchase Request Tab
// ============================================================
class _PurchaseRequestTab extends StatefulWidget {
  final List<String> statuses;
  const _PurchaseRequestTab({required this.statuses});

  @override
  State<_PurchaseRequestTab> createState() => _PurchaseRequestTabState();
}

class _PurchaseRequestTabState extends State<_PurchaseRequestTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _records;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.get('/purchase-requests');
      if (!mounted) return;
      setState(() { _records = res.data as List<dynamic>; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.isEmpty) return '';
    // If it's already a plain Y-m-d string, return as-is (no timezone shift)
    final plainDateMatch = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(text);
    if (plainDateMatch != null) return text;
    // For ISO8601 strings (e.g. 2026-09-16T16:00:00.000000Z), parse and
    // format using the date portion directly to avoid UTC-to-local shift
    final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (isoMatch != null) return isoMatch.group(1)!;
    final date = DateTime.tryParse(text);
    if (date != null) return DateFormat('yyyy-MM-dd').format(date);
    return text;
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '';
    double? amount;
    if (value is num) {
      amount = value.toDouble();
    } else {
      amount = double.tryParse(value.toString());
    }
    if (amount == null) return value.toString();
    final peso = String.fromCharCode(8369);
    final formatted = NumberFormat('#,##0.00', 'en_US').format(amount);
    return '$peso$formatted';
  }

  double? _parseAmount(String text) {
    final cleaned = text.replaceAll(',', '').replaceAll(String.fromCharCode(8369), '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _showForm({Map<String, dynamic>? record}) async {
    final formKey = GlobalKey<FormState>();
    final dateOfCreation = TextEditingController(text: _formatDate(record?['date_of_creation']));
    final purpose = TextEditingController(text: record?['purpose'] ?? '');
    final totalAmount = TextEditingController(text: record?['total_amount']?.toString() ?? '');
    final purchaseRequestNumber = TextEditingController(text: record?['purchase_request_number'] ?? '');
    final dateIssued = TextEditingController(text: _formatDate(record?['date_issued']));
    final receivingOffice = TextEditingController(text: record?['receiving_office'] ?? '');
    final remarks = TextEditingController(text: record?['remarks'] ?? '');
    String status = record?['status'] ?? 'Pending';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add Purchase Request' : 'Edit Purchase Request'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: dateOfCreation, decoration: const InputDecoration(labelText: 'Date of Creation (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  TextFormField(controller: purpose, decoration: const InputDecoration(labelText: 'Purpose'), maxLines: 3),
                  const SizedBox(height: 8),
                  TextFormField(controller: totalAmount, decoration: const InputDecoration(labelText: 'Total Amount'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextFormField(controller: purchaseRequestNumber, decoration: const InputDecoration(labelText: 'Purchase Request Number')),
                  const SizedBox(height: 8),
                  TextFormField(controller: dateIssued, decoration: const InputDecoration(labelText: 'Date Issued (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: widget.statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDialogState(() => status = v ?? 'Pending'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: receivingOffice, decoration: const InputDecoration(labelText: 'Receiving Office')),
                  const SizedBox(height: 8),
                  TextFormField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks'), maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final payload = <String, dynamic>{
                  'date_of_creation': dateOfCreation.text.trim().isEmpty ? null : dateOfCreation.text.trim(),
                  'purpose': purpose.text.trim(),
                  'total_amount': _parseAmount(totalAmount.text) ?? 0,
                  'purchase_request_number': purchaseRequestNumber.text.trim(),
                  'date_issued': dateIssued.text.trim().isEmpty ? null : dateIssued.text.trim(),
                  'status': status,
                  'receiving_office': receivingOffice.text.trim(),
                  'remarks': remarks.text.trim(),
                };
                Navigator.pop(context);
                _save(record?['id'], payload);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(int? id, Map<String, dynamic> payload) async {
    try {
      if (id == null) {
        await ApiClient.post('/purchase-requests', data: payload);
      } else {
        await ApiClient.put('/purchase-requests/$id', data: payload);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${record['purpose']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/purchase-requests/${record['id']}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  (List<String>, List<List<String>>) _buildExportData() {
    final headers = ['Date of Creation', 'Purpose', 'Total Amount', 'Purchase Request Number',
        'Date Issued', 'Status', 'Receiving Office', 'Remarks'];
    final data = (_records ?? []).map((r) {
      final m = r as Map<String, dynamic>;
      return [
        _formatDate(m['date_of_creation']),
        m['purpose']?.toString() ?? '',
        _formatAmount(m['total_amount']),
        m['purchase_request_number']?.toString() ?? '',
        _formatDate(m['date_issued']),
        m['status']?.toString() ?? '',
        m['receiving_office']?.toString() ?? '',
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $outputPath')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], subject: fileName);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $fileName')));
  }

  String _exportFileName() => 'purchase_requests_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

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
      String esc(String s) => s.replaceAll(amp, '${amp}amp;').replaceAll('<', '${amp}lt;').replaceAll('>', '${amp}gt;');
      final buf = StringBuffer()
        ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">')
        ..writeln('<head><meta charset="utf-8"><style>body{font-family:Arial;font-size:10pt}table{border-collapse:collapse;width:100%}th,td{border:1px solid #000;padding:4pt}th{background:#d9d9d9;font-weight:bold}</style></head><body>')
        ..writeln('<h2>Purchase Requests</h2><table><thead><tr>');
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text('Purchase Requests', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
    super.build(context);
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final list = _records ?? [];
    const columns = [
      DataColumn(label: Text('Date Created')),
      DataColumn(label: Text('Purpose')),
      DataColumn(label: Text('Total Amount')),
      DataColumn(label: Text('PR Number')),
      DataColumn(label: Text('Date Issued')),
      DataColumn(label: Text('Status')),
      DataColumn(label: Text('Receiving Office')),
      DataColumn(label: Text('Remarks')),
      DataColumn(label: Text('Actions')),
    ];

    final rows = list.map<DataRow>((r) {
      final m = r as Map<String, dynamic>;
      return DataRow(cells: [
        DataCell(Text(_formatDate(m['date_of_creation']))),
        DataCell(SizedBox(width: 220, child: Text(m['purpose']?.toString() ?? '', softWrap: true))),
        DataCell(Text(_formatAmount(m['total_amount']))),
        DataCell(Text(m['purchase_request_number']?.toString() ?? '')),
        DataCell(Text(_formatDate(m['date_issued']))),
        DataCell(_statusBadge(m['status']?.toString() ?? '')),
        DataCell(Text(m['receiving_office']?.toString() ?? '')),
        DataCell(SizedBox(width: 220, child: Text(m['remarks']?.toString() ?? '', softWrap: true))),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(record: m)),
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
            children: [
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: _load),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Purchase Request'),
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
            ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'No records yet', subtitle: 'Add a purchase request to start tracking')
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
      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Export')]),
    );
  }

  Widget _statusBadge(String status) {
    if (status == 'Received' || status == 'Completed' || status == 'Approved') {
      return StatusBadge.success(status);
    } else if (status == 'Pending') {
      return StatusBadge.warning(status);
    } else if (status == 'Processing' || status == 'Released') {
      return StatusBadge.info(status);
    }
    return Text(status);
  }
}

// ============================================================
// Reimbursement Tab
// ============================================================
class _ReimbursementTab extends StatefulWidget {
  final List<String> statuses;
  const _ReimbursementTab({required this.statuses});

  @override
  State<_ReimbursementTab> createState() => _ReimbursementTabState();
}

class _ReimbursementTabState extends State<_ReimbursementTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _records;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.get('/reimbursements');
      if (!mounted) return;
      setState(() { _records = res.data as List<dynamic>; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.isEmpty) return '';
    // If it's already a plain Y-m-d string, return as-is (no timezone shift)
    final plainDateMatch = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(text);
    if (plainDateMatch != null) return text;
    // For ISO8601 strings (e.g. 2026-09-16T16:00:00.000000Z), parse and
    // format using the date portion directly to avoid UTC-to-local shift
    final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (isoMatch != null) return isoMatch.group(1)!;
    final date = DateTime.tryParse(text);
    if (date != null) return DateFormat('yyyy-MM-dd').format(date);
    return text;
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '';
    double? amount;
    if (value is num) {
      amount = value.toDouble();
    } else {
      amount = double.tryParse(value.toString());
    }
    if (amount == null) return value.toString();
    final peso = String.fromCharCode(8369);
    final formatted = NumberFormat('#,##0.00', 'en_US').format(amount);
    return '$peso$formatted';
  }

  double? _parseAmount(String text) {
    final cleaned = text.replaceAll(',', '').replaceAll(String.fromCharCode(8369), '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Shows every individual receipt amount plus the summed total, e.g.
  /// "₱500.00 + ₱300.00 = ₱800.00". Falls back to the backend's computed
  /// `receipt_total` if `receipt_amounts` isn't present.
  String _formatReceiptTotal(Map<String, dynamic> m) {
    final amounts = (m['receipt_amounts'] as List<dynamic>?)
        ?.map((a) => (a is num) ? a.toDouble() : double.tryParse(a.toString()) ?? 0)
        .toList();
    if (amounts == null || amounts.isEmpty) {
      final fallback = m['receipt_total'];
      if (fallback == null) return '';
      return _formatAmount(fallback);
    }
    final total = amounts.fold<double>(0, (sum, v) => sum + v);
    final formatted = _formatAmount(total);
    if (amounts.length <= 1) return formatted;
    final parts = amounts.map(_formatAmount).join(' + ');
    return '$parts = $formatted';
  }

  Future<void> _showForm({Map<String, dynamic>? record}) async {
    final formKey = GlobalKey<FormState>();
    final dateOfCreation = TextEditingController(text: _formatDate(record?['date_of_creation']));
    final purpose = TextEditingController(text: record?['purpose'] ?? '');
    final totalAmount = TextEditingController(text: record?['total_amount']?.toString() ?? '');
    final receiptAmountsRaw = (record?['receipt_amounts'] as List<dynamic>?) ?? [];
    final receiptAmounts = <TextEditingController>[
      for (final amount in receiptAmountsRaw) TextEditingController(text: amount.toString()),
      if (receiptAmountsRaw.isEmpty) TextEditingController(),
    ];
    final purchaseRequestNumber = TextEditingController(text: record?['purchase_request_number'] ?? '');
    final dateIssued = TextEditingController(text: _formatDate(record?['date_issued']));
    final receivingOffice = TextEditingController(text: record?['receiving_office'] ?? '');
    final remarks = TextEditingController(text: record?['remarks'] ?? '');
    final orDate = TextEditingController(text: _formatDate(record?['or_date']));
    final attendanceReceivedDate = TextEditingController(text: _formatDate(record?['attendance_received_date']));
    String status = record?['status'] ?? 'Pending';
    bool orReceivedOriginal = record?['or_received_original'] == true;
    bool received = record?['received'] == true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add Reimbursement' : 'Edit Reimbursement'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: dateOfCreation, decoration: const InputDecoration(labelText: 'Date of Creation (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  TextFormField(controller: purpose, decoration: const InputDecoration(labelText: 'Purpose'), maxLines: 3),
                  const SizedBox(height: 8),
                  TextFormField(controller: totalAmount, decoration: const InputDecoration(labelText: 'Total Amount'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Total Amount of Receipt (up to 10)', style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < receiptAmounts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: receiptAmounts[i],
                              decoration: InputDecoration(labelText: 'Receipt ${i + 1} Amount'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          if (receiptAmounts.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.error),
                              onPressed: () => setDialogState(() => receiptAmounts.removeAt(i)),
                            ),
                        ],
                      ),
                    ),
                  if (receiptAmounts.length < 10)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setDialogState(() => receiptAmounts.add(TextEditingController())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Receipt Amount'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(controller: purchaseRequestNumber, decoration: const InputDecoration(labelText: 'Purchase Request Number')),
                  const SizedBox(height: 8),
                  TextFormField(controller: dateIssued, decoration: const InputDecoration(labelText: 'Date Issued (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: widget.statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDialogState(() => status = v ?? 'Pending'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: receivingOffice, decoration: const InputDecoration(labelText: 'Receiving Office')),
                  const SizedBox(height: 8),
                  TextFormField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks'), maxLines: 3),
                  const Divider(height: 24),
                  TextFormField(controller: orDate, decoration: const InputDecoration(labelText: 'OR Date (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  CheckboxListTile(title: const Text('OR Received (Original)'), value: orReceivedOriginal,
                    onChanged: (v) => setDialogState(() => orReceivedOriginal = v ?? false), contentPadding: EdgeInsets.zero, dense: true),
                  const SizedBox(height: 8),
                  TextFormField(controller: attendanceReceivedDate, decoration: const InputDecoration(labelText: 'Attendance Received Date (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  CheckboxListTile(title: const Text('Received'), value: received,
                    onChanged: (v) => setDialogState(() => received = v ?? false), contentPadding: EdgeInsets.zero, dense: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final payload = <String, dynamic>{
                  'date_of_creation': dateOfCreation.text.trim().isEmpty ? null : dateOfCreation.text.trim(),
                  'purpose': purpose.text.trim(),
                  'total_amount': _parseAmount(totalAmount.text) ?? 0,
                  'receipt_amounts': receiptAmounts
                      .map((c) => _parseAmount(c.text))
                      .whereType<double>()
                      .toList(),
                  'purchase_request_number': purchaseRequestNumber.text.trim(),
                  'date_issued': dateIssued.text.trim().isEmpty ? null : dateIssued.text.trim(),
                  'status': status,
                  'receiving_office': receivingOffice.text.trim(),
                  'remarks': remarks.text.trim(),
                  'or_date': orDate.text.trim().isEmpty ? null : orDate.text.trim(),
                  'or_received_original': orReceivedOriginal,
                  'attendance_received_date': attendanceReceivedDate.text.trim().isEmpty ? null : attendanceReceivedDate.text.trim(),
                  'received': received,
                };
                Navigator.pop(context);
                _save(record?['id'], payload);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(int? id, Map<String, dynamic> payload) async {
    try {
      if (id == null) {
        await ApiClient.post('/reimbursements', data: payload);
      } else {
        await ApiClient.put('/reimbursements/$id', data: payload);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${record['purpose']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/reimbursements/${record['id']}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  (List<String>, List<List<String>>) _buildExportData() {
    final headers = ['Date of Creation', 'Purpose', 'Total Amount', 'Total Amount of Receipt', 'Purchase Request Number',
        'Date Issued', 'Status', 'Receiving Office', 'Remarks', 'OR Date', 'OR Received (Original)',
        'Attendance Received Date', 'Received'];
    final data = (_records ?? []).map((r) {
      final m = r as Map<String, dynamic>;
      return [
        _formatDate(m['date_of_creation']),
        m['purpose']?.toString() ?? '',
        _formatAmount(m['total_amount']),
        _formatReceiptTotal(m),
        m['purchase_request_number']?.toString() ?? '',
        _formatDate(m['date_issued']),
        m['status']?.toString() ?? '',
        m['receiving_office']?.toString() ?? '',
        m['remarks']?.toString() ?? '',
        _formatDate(m['or_date']),
        m['or_received_original'] == true ? 'Yes' : 'No',
        _formatDate(m['attendance_received_date']),
        m['received'] == true ? 'Yes' : 'No',
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $outputPath')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], subject: fileName);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $fileName')));
  }

  String _exportFileName() => 'reimbursements_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

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
      String esc(String s) => s.replaceAll(amp, '${amp}amp;').replaceAll('<', '${amp}lt;').replaceAll('>', '${amp}gt;');
      final buf = StringBuffer()
        ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">')
        ..writeln('<head><meta charset="utf-8"><style>body{font-family:Arial;font-size:10pt}table{border-collapse:collapse;width:100%}th,td{border:1px solid #000;padding:4pt}th{background:#d9d9d9;font-weight:bold}</style></head><body>')
        ..writeln('<h2>Reimbursements</h2><table><thead><tr>');
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text('Reimbursements', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
    super.build(context);
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final list = _records ?? [];
    const columns = [
      DataColumn(label: Text('Date Created')),
      DataColumn(label: Text('Purpose')),
      DataColumn(label: Text('Total')),
      DataColumn(label: Text('Total Amount of Receipt')),
      DataColumn(label: Text('PR Number')),
      DataColumn(label: Text('Date Issued')),
      DataColumn(label: Text('Status')),
      DataColumn(label: Text('Office')),
      DataColumn(label: Text('Remarks')),
      DataColumn(label: Text('OR Date')),
      DataColumn(label: Text('OR Orig')),
      DataColumn(label: Text('Att. Date')),
      DataColumn(label: Text('Received')),
      DataColumn(label: Text('Actions')),
    ];

    final rows = list.map<DataRow>((r) {
      final m = r as Map<String, dynamic>;
      return DataRow(cells: [
        DataCell(Text(_formatDate(m['date_of_creation']))),
        DataCell(SizedBox(width: 220, child: Text(m['purpose']?.toString() ?? '', softWrap: true))),
        DataCell(Text(_formatAmount(m['total_amount']))),
        DataCell(SizedBox(width: 220, child: Text(_formatReceiptTotal(m), softWrap: true))),
        DataCell(Text(m['purchase_request_number']?.toString() ?? '')),
        DataCell(Text(_formatDate(m['date_issued']))),
        DataCell(_statusBadge(m['status']?.toString() ?? '')),
        DataCell(Text(m['receiving_office']?.toString() ?? '')),
        DataCell(SizedBox(width: 220, child: Text(m['remarks']?.toString() ?? '', softWrap: true))),
        DataCell(Text(_formatDate(m['or_date']))),
        DataCell(m['or_received_original'] == true ? StatusBadge.success('Yes') : StatusBadge.warning('No')),
        DataCell(Text(_formatDate(m['attendance_received_date']))),
        DataCell(m['received'] == true ? StatusBadge.success('Yes') : StatusBadge.warning('No')),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(record: m)),
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
            children: [
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: _load),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Reimbursement'),
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
            ? const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No records yet', subtitle: 'Add a reimbursement to start tracking')
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
      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Export')]),
    );
  }

  Widget _statusBadge(String status) {
    if (status == 'Received' || status == 'Completed' || status == 'Approved') {
      return StatusBadge.success(status);
    } else if (status == 'Pending') {
      return StatusBadge.warning(status);
    } else if (status == 'Processing' || status == 'Released') {
      return StatusBadge.info(status);
    }
    return Text(status);
  }
}
