import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';

class CodeMonitoringScreen extends StatefulWidget {
  const CodeMonitoringScreen({super.key});

  @override
  State<CodeMonitoringScreen> createState() => CodeMonitoringScreenState();
}

class CodeMonitoringScreenState extends State<CodeMonitoringScreen>
    with SingleTickerProviderStateMixin {
  static const _types = ['IC', 'EC', 'MEMO', 'CA'];
  late final TabController _tabs;
  final _search = TextEditingController();
  String _type = 'IC';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _types.length, vsync: this);
    load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.get('/code-monitoring');
      if (!mounted) return;
      setState(() {
        _records = (response.data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
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

  Future<void> _showForm([Map<String, dynamic>? record]) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: record?['code']?.toString() ?? '');
    final title =
        TextEditingController(text: record?['title']?.toString() ?? '');
    var type = record?['type']?.toString() ?? _type;
    var date = record == null
        ? DateTime.now()
        : DateTime.parse(record['date'].toString());

    final route = DialogRoute<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add code' : 'Edit code'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final item in _types)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => type = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: code,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: 'Code'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: title,
                      maxLength: 255,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && dialogContext.mounted) {
                          setDialogState(() => date = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('yyyy-MM-dd').format(date)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'type': type,
                  'code': code.text.trim(),
                  'title': title.text.trim(),
                  'date': DateFormat('yyyy-MM-dd').format(date),
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final payload = await Navigator.of(context).push(route);
    await route.completed;
    code.dispose();
    title.dispose();
    if (payload == null || !mounted) return;

    setState(() => _saving = true);
    try {
      if (record == null) {
        await ApiClient.post('/code-monitoring', data: payload);
      } else {
        await ApiClient.put('/code-monitoring/${record['id']}', data: payload);
      }
      if (!mounted) return;
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Code saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save code: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete code?'),
        content: Text('Delete "${record['code']}" from code monitoring?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ApiClient.delete('/code-monitoring/${record['id']}');
      if (!mounted) return;
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Code deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete code: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: load);
    final search = _search.text.trim().toLowerCase();
    final records = _records.where((record) {
      if (record['type'] != _type) return false;
      return '${record['code']} ${record['title']} ${record['date']}'
          .toLowerCase()
          .contains(search);
    }).toList();

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          onTap: (index) => setState(() => _type = _types[index]),
          tabs: [for (final type in _types) Tab(text: type)],
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search code or title',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _showForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add code'),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const EmptyState(
                  icon: Icons.tag,
                  title: 'No matching codes',
                  subtitle: 'Add a code to start monitoring.',
                )
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Title')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final record in records)
                          DataRow(cells: [
                            DataCell(Text(record['code'].toString())),
                            DataCell(Text(record['title'].toString())),
                            DataCell(Text(record['date'].toString())),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed:
                                      _saving ? null : () => _showForm(record),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed:
                                      _saving ? null : () => _delete(record),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            )),
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
