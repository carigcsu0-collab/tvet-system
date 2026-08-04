import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';

class AssessorsScreen extends StatefulWidget {
  const AssessorsScreen({super.key});

  @override
  State<AssessorsScreen> createState() => _AssessorsScreenState();
}

class _AssessorsScreenState extends State<AssessorsScreen> {
  List<dynamic>? _assessors;
  List<dynamic>? _centers;
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        ApiClient.get('/assessors'),
        ApiClient.get('/centers'),
      ]);
      if (!mounted) return;
      setState(() {
        _assessors = results[0].data as List<dynamic>?;
        _centers = results[1].data as List<dynamic>?;
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

  List<String> _allQualifications() {
    final allQuals = <String>[];
    for (final c in _centers ?? []) {
      final quals = (c['qualifications'] as List<dynamic>? ?? [])
          .map((q) => q.toString());
      allQuals.addAll(quals);
    }
    return allQuals.toSet().toList()..sort();
  }

  String _friendlyError(Object e) {
    try {
      if (e is DioException) {
        final res = e.response;
        final data = res?.data;
        if (data is Map<String, dynamic>) {
          final msg = (data['message']?.toString() ?? '').trim();
          final errors = data['errors'];
          if (errors is Map<String, dynamic> && errors.isNotEmpty) {
            final parts = <String>[];
            errors.forEach((k, v) {
              if (v is List && v.isNotEmpty) parts.add(v.first.toString());
            });
            if (parts.isNotEmpty) return parts.join('\n');
          }
          if (msg.isNotEmpty) return msg;
        } else if (data is String && data.trim().isNotEmpty) {
          return data.trim();
        }
        if (res?.statusCode == 422) return 'Validation failed. Check required fields.';
        if (res?.statusCode == 500) return 'Server error. Please try again.';
      }
    } catch (_) {}
    return e.toString();
  }

  Future<void> _delete(Map<String, dynamic> assessor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assessor'),
        content: Text('Delete ${assessor['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/assessors/${assessor['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessor deleted')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _showForm([Map<String, dynamic>? assessor]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(
      text: assessor?['name']?.toString() ?? '',
    );
    final accreditationNumber = TextEditingController(
      text: assessor?['accreditation_number']?.toString() ?? '',
    );
    final mobileNumber = TextEditingController(
      text: assessor?['mobile_number']?.toString() ?? '',
    );
    List<String> selectedQualifications = (assessor?['qualifications'] as List<dynamic>? ?? [])
        .map((q) => q.toString())
        .toList();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(assessor == null ? 'Add Assessor' : 'Edit Assessor'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: accreditationNumber,
                      decoration: const InputDecoration(
                        labelText: 'Accreditation Number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mobileNumber,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_allQualifications().isNotEmpty) ...[
                      Text('Qualifications',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ..._allQualifications().map((q) {
                        final checked = selectedQualifications.contains(q);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(q),
                          value: checked,
                          onChanged: (v) => setDialogState(() {
                            if (v == true) {
                              selectedQualifications.add(q);
                            } else {
                              selectedQualifications.remove(q);
                            }
                          }),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => submitting = true);
                      final data = <String, dynamic>{
                        'name': name.text.trim(),
                        'accreditation_number': accreditationNumber.text.trim(),
                        'mobile_number': mobileNumber.text.trim(),
                        'qualifications': selectedQualifications,
                      };
                      final ok = assessor == null
                          ? await _createAssessor(data)
                          : await _updateAssessor(assessor['id'] as int, data);
                      setDialogState(() => submitting = false);
                      if (ok && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(assessor == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _createAssessor(Map<String, dynamic> data) async {
    try {
      await ApiClient.post('/assessors', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessor created')),
        );
      }
      _load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${_friendlyError(e)}')),
        );
      }
      return false;
    }
  }

  Future<bool> _updateAssessor(int id, Map<String, dynamic> data) async {
    try {
      await ApiClient.put('/assessors/$id', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessor updated')),
        );
      }
      _load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${_friendlyError(e)}')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final list = _assessors ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.csuMaroon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.person, color: AppTheme.csuMaroon, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  '${list.length} assessor${list.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Assessor'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No assessors yet',
                  subtitle: 'Add assessors to manage assessment center personnel',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateColor.resolveWith(
                          (_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Accreditation No.')),
                        DataColumn(label: Text('Mobile Number')),
                        DataColumn(label: Text('Qualifications')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: list.map<DataRow>((a) {
                        final name = a['name']?.toString() ?? 'Unknown';
                        final accNum = a['accreditation_number']?.toString() ?? '';
                        final mobileNum = a['mobile_number']?.toString() ?? '';
                        final quals = (a['qualifications'] as List<dynamic>? ?? [])
                            .join(', ');
                        return DataRow(
                          cells: [
                            DataCell(Text(name)),
                            DataCell(Text(accNum.isEmpty ? 'None' : accNum)),
                            DataCell(Text(mobileNum.isEmpty ? 'None' : mobileNum)),
                            DataCell(Text(quals.isEmpty ? 'None' : quals)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit',
                                  onPressed: () => _showForm(a),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: AppTheme.error),
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(a),
                                ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
