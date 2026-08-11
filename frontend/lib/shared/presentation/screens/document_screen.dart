import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/records_refresh.dart';
import '../widgets/table_editor.dart';
import '../widgets/ui_components.dart';
import 'print_preview_screen.dart';

class FieldConfig {
  final String name;
  final String label;
  final int maxLines;

  const FieldConfig({
    required this.name,
    required this.label,
    this.maxLines = 1,
  });
}

class DocumentScreen extends StatefulWidget {
  final String slug;
  final String title;
  final IconData icon;
  final List<FieldConfig> fields;
  final bool showLetterhead;
  final bool allowTable;

  const DocumentScreen({
    super.key,
    required this.slug,
    required this.title,
    required this.icon,
    required this.fields,
    this.showLetterhead = false,
    this.allowTable = false,
  });

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = [];
  final _codeController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _coordinator;
  String _coordinatorTitle = 'TVET Coordinator';
  List<dynamic>? _users;
  String? _selectedUserId;
  List<String> _selectedDesignations = [];
  bool _loading = true;
  bool _generating = false;
  Map<String, dynamic>? _generated;
  List<Map<String, String>>? _table;

  @override
  void initState() {
    super.initState();
    for (final _ in widget.fields) {
      _controllers.add(TextEditingController());
    }
    _dateController.text = DateFormat('MMMM dd, yyyy').format(_date);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/document-types/${widget.slug}/next-code'),
        ApiClient.get('/users'),
        ApiClient.get('/settings/DEFAULT_COORDINATOR_NAME'),
        ApiClient.get('/settings/DEFAULT_COORDINATOR_TITLE'),
      ]);
      final data = results[0].data as Map<String, dynamic>;
      _codeController.text = (data['code'] as String?) ?? '';
      final coordNameResp = results[2].data as Map<String, dynamic>?;
      final coordTitleResp = results[3].data as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _users = results[1].data as List<dynamic>?;
        if (coordNameResp != null && coordNameResp['value'] != null) {
          _coordinator = coordNameResp['value'].toString();
        }
        if (coordTitleResp != null && coordTitleResp['value'] != null) {
          _coordinatorTitle = coordTitleResp['value'].toString();
        }
      });
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _generating = true);
    final recordsRefresh = context.read<RecordsRefresh>();
    try {
      final payload = <String, dynamic>{};
      for (int i = 0; i < widget.fields.length; i++) {
        payload[widget.fields[i].name] = _controllers[i].text.trim();
      }
      payload['date'] = _dateController.text.trim();
      if (_selectedSignatoryName.isNotEmpty) {
        payload['coordinatorName'] = _selectedSignatoryName;
        payload['coordinatorTitle'] = _selectedDesignations.isNotEmpty
            ? _selectedDesignations.join(', ')
            : _designationsFor(_selectedUserId).join(', ');
      } else {
        payload['coordinatorName'] = _coordinator ?? '';
        payload['coordinatorTitle'] = _coordinatorTitle;
      }
      if (widget.allowTable && _table != null) {
        payload['table'] = _table;
      }
      final res = await ApiClient.post(
        '/documents/${widget.slug}',
        data: payload,
      );
      setState(() => _generated = res.data as Map<String, dynamic>);
      recordsRefresh.refresh();
      _loadData();
    } finally {
      setState(() => _generating = false);
    }
  }

  List<DropdownMenuItem<String>> _buildUserItems() {
    final items = <DropdownMenuItem<String>>[];
    for (final u in _users ?? []) {
      final id = u['id']?.toString() ?? '';
      final name = u['name']?.toString() ?? '';
      final ext = u['extension_name']?.toString() ?? '';
      final fullName = ext.isNotEmpty ? '$name $ext' : name;
      items.add(DropdownMenuItem(
        value: id,
        child: Text(fullName),
      ));
    }
    return items;
  }

  List<String> _designationsFor(String? userId) {
    if (userId == null) return [];
    final u = _users?.firstWhere(
      (e) => e['id']?.toString() == userId,
      orElse: () => <String, dynamic>{},
    );
    if (u == null) return [];
    return (u['designations'] as List<dynamic>? ?? [])
        .map((d) => d.toString())
        .toList();
  }

  String get _selectedSignatoryName {
    if (_selectedUserId == null) return _coordinator ?? '';
    final u = _users?.firstWhere(
      (e) => e['id']?.toString() == _selectedUserId,
      orElse: () => <String, dynamic>{},
    );
    if (u == null) return '';
    final name = u['name']?.toString() ?? '';
    final ext = u['extension_name']?.toString() ?? '';
    return ext.isNotEmpty ? '$name $ext' : name;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _dateController.text = DateFormat('MMMM dd, yyyy').format(picked);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _dateController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showLetterhead) ...[
                      const UniversityLetterhead(),
                    ] else ...[
                      SectionHeader(
                        icon: widget.icon,
                        title: widget.title,
                        subtitle: 'Fill in the details below',
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                    ],
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _codeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Document Code',
                          isDense: true,
                          prefixIcon: Icon(Icons.tag, size: 18),
                        ),
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: 'Date',
                          isDense: true,
                          prefixIcon: const Icon(Icons.calendar_today, size: 18),
                          suffixIcon: IconButton(
                            tooltip: 'Pick a date',
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            onPressed: _pickDate,
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    if (_users != null && _users!.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spaceMd),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedUserId,
                        decoration: const InputDecoration(
                          labelText: 'Signatory Name',
                          prefixIcon: Icon(Icons.person, size: 18),
                          isDense: true,
                        ),
                        items: _buildUserItems(),
                        onChanged: (v) => setState(() {
                          _selectedUserId = v;
                          _selectedDesignations = [];
                        }),
                      ),
                      if (_selectedUserId != null &&
                          _designationsFor(_selectedUserId).isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        Text('Designations',
                            style: Theme.of(context).textTheme.titleSmall),
                        ..._designationsFor(_selectedUserId).map((d) {
                          final checked = _selectedDesignations.contains(d);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(d),
                            value: checked,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedDesignations.add(d);
                              } else {
                                _selectedDesignations.remove(d);
                              }
                            }),
                          );
                        }),
                      ],
                    ] else if (_coordinator != null) ...[
                      const SizedBox(height: AppTheme.spaceSm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.csuMaroon.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 16, color: AppTheme.csuMaroon),
                            const SizedBox(width: 6),
                            Text(
                              'Coordinator: $_coordinator',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceLg),
                    if (widget.allowTable) ...[
                      const SectionHeader(
                        icon: Icons.table_chart,
                        imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                        title: 'Table (optional)',
                        subtitle: 'Add tabular data to the document',
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      TableEditor(
                        onChanged: (table) => setState(() => _table = table),
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                    ],
                    ...List.generate(widget.fields.length, (i) {
                      final f = widget.fields[i];
                      final isTo = f.name == 'to' || f.name == 'recipient';
                      final isBody = f.name == 'body';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                        child: TextFormField(
                          controller: _controllers[i],
                          decoration: InputDecoration(
                            labelText: isTo
                                ? 'To (Name, Designation, Office, Address)'
                                : f.label,
                            hintText: isTo
                                ? 'e.g. Juan Dela Cruz, Program Coordinator, TVET Office, Carig Campus, Tuguegarao City'
                                : null,
                          ),
                          minLines: isBody ? 5 : (isTo ? 1 : 1),
                          maxLines: isTo ? 4 : f.maxLines,
                          keyboardType: isBody || isTo
                              ? TextInputType.multiline
                              : TextInputType.text,
                          textAlign: isBody
                              ? TextAlign.justify
                              : TextAlign.start,
                          validator: f.name == 'from' || f.name == 'subject'
                              ? null
                              : (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                        ),
                      );
                    }),
                    const SizedBox(height: AppTheme.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _generating ? null : _save,
                        icon: _generating
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_generating ? 'Saving...' : 'Save Document'),
                      ),
                    ),
                    if (_generated != null) ...[
                      const SizedBox(height: AppTheme.spaceLg),
                      SuccessCard(
                        code: _generated!['code']?.toString() ?? '',
                        onView: () {
                          final code = _generated!['code']?.toString() ?? '';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PrintPreviewScreen(code: code),
                            ),
                          );
                        },
                      ),
                    ],
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
