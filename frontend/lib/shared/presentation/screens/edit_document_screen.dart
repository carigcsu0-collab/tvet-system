import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
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
  final _controllers = <String, TextEditingController>{};
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _record;

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
      for (final entry in payload.entries) {
        _controllers[entry.key] =
            TextEditingController(text: entry.value?.toString() ?? '');
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
      for (final entry in _controllers.entries) {
        payload[entry.key] = entry.value.text.trim();
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
                  ..._controllers.entries.map((entry) {
                    final isBody = entry.key == 'body';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: TextFormField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
                        ),
                        maxLines: isBody ? 8 : null,
                        minLines: isBody ? 5 : null,
                        keyboardType: isBody
                            ? TextInputType.multiline
                            : TextInputType.text,
                        textAlign: isBody ? TextAlign.justify : TextAlign.start,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    );
                  }),
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
