import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/table_editor.dart';
import '../widgets/ui_components.dart';

class EditDocumentScreen extends StatefulWidget {
  final String code;

  const EditDocumentScreen({super.key, required this.code});

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _greetingsController = TextEditingController();
  final _tableEditorKey = GlobalKey<TableEditorState>();
  final _controllers = <String, TextEditingController>{};
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _record;
  List<Map<String, String>>? _table;
  final _editableKeys = [
    'to', 'recipient', 'organization', 'address', 'from', 'subject',
    'body', 'date', 'greetings',
    'coordinatorName', 'coordinatorTitle',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/documents/${widget.code}');
      final record = res.data as Map<String, dynamic>;
      final payload = (record['payload'] as Map<String, dynamic>?) ?? {};
      _codeController.text = record['code']?.toString() ?? '';
      for (final key in _editableKeys) {
        if (payload[key] != null) {
          _controllers[key] =
              TextEditingController(text: payload[key]?.toString() ?? '');
        }
      }
      // Ensure greetings controller always exists
      if (!_controllers.containsKey('greetings')) {
        _controllers['greetings'] = TextEditingController(text: 'Sir:');
      }
      // Load table from payload
      if (payload['table'] != null) {
        _table = (payload['table'] as List<dynamic>)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      }
      // Load footerBody separately so it renders after table
      if (payload['footerBody'] != null) {
        _controllers['footerBody'] =
            TextEditingController(text: payload['footerBody']?.toString() ?? '');
      }
      _record = record;
    } catch (e) {
      _record = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{};
      // Preserve code and year from original record
      final originalPayload = (_record!['payload'] as Map<String, dynamic>?) ?? {};
      payload['code'] = _codeController.text.trim();
      payload['year'] = originalPayload['year'] ?? DateTime.now().year;
      for (final entry in _controllers.entries) {
        payload[entry.key] = entry.value.text.trim();
      }
      // Save table if edited
      if (_table != null) {
        payload['table'] = _table;
        // Save column order explicitly
        final headers = _tableEditorKey.currentState?.headers ?? <String>[];
        if (headers.isNotEmpty) {
          payload['tableColumns'] = headers;
        }
      } else if (originalPayload['table'] != null) {
        payload['table'] = originalPayload['table'];
        if (originalPayload['tableColumns'] != null) {
          payload['tableColumns'] = originalPayload['tableColumns'];
        }
      }
      await ApiClient.put(
        '/documents/${widget.code}',
        data: {
          'payload': payload,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _greetingsController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Document')),
        body: const LoadingState(),
      );
    }

    if (_record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Document')),
        body: const EmptyState(
          icon: Icons.description_outlined,
          title: 'Document not found',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Document')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _codeController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Document Code',
                      isDense: true,
                      prefixIcon: Icon(Icons.tag, size: 18),
                      labelStyle: TextStyle(color: AppTheme.success),
                    ),
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  // Render non-footer fields (to, from, subject, body, etc.)
                  ..._controllers.entries.where((e) =>
                      e.key != 'footerBody' && e.key != 'greetings').map((entry) {
                    final isBody = entry.key == 'body';
                    final isReadOnly = entry.key == 'code' ||
                        entry.key == 'year' ||
                        entry.key == 'coordinatorName' ||
                        entry.key == 'coordinatorTitle';
                    final labelMap = {
                      'to': 'To (Name, Designation, Office, Address)',
                      'recipient': 'To (Name, Designation, Office, Address)',
                      'organization': 'Designation / Office',
                      'address': 'Address',
                      'from': 'Thru (Office)',
                      'subject': 'Subject',
                      'body': 'Body',
                      'date': 'Date',
                      'coordinatorName': 'Signatory Name',
                      'coordinatorTitle': 'Signatory Title',
                    };
                    final label = labelMap[entry.key] ??
                        entry.key.replaceAll('_', ' ').toUpperCase();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: TextFormField(
                        controller: entry.value,
                        readOnly: isReadOnly,
                        decoration: InputDecoration(
                          labelText: label,
                        ),
                        maxLines: isBody ? 8 : null,
                        minLines: isBody ? 5 : null,
                        keyboardType: isBody
                            ? TextInputType.multiline
                            : TextInputType.text,
                        textAlign: isBody ? TextAlign.justify : TextAlign.start,
                        validator: isReadOnly
                            ? null
                            : (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    );
                  }),
                  // Greetings field
                  if (_controllers.containsKey('greetings'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: TextFormField(
                        controller: _controllers['greetings'],
                        decoration: const InputDecoration(
                          labelText: 'Greetings',
                          hintText: 'e.g. Sir: / Madam:',
                        ),
                      ),
                    ),
                  // Table editor
                  const SizedBox(height: AppTheme.spaceMd),
                  TableEditor(
                    key: _tableEditorKey,
                    initialTable: _table,
                    onChanged: (table) => setState(() => _table = table),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Footer body field after table
                  if (_controllers.containsKey('footerBody'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: TextFormField(
                        controller: _controllers['footerBody'],
                        decoration: const InputDecoration(
                          labelText: 'Footer Body (Optional)',
                        ),
                        maxLines: 3,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  const SizedBox(height: AppTheme.spaceMd),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Update'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
