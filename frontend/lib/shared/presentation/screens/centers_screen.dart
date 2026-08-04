import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';
import 'center_report_print_screen.dart';

class CentersScreen extends StatefulWidget {
  const CentersScreen({super.key});

  @override
  State<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends State<CentersScreen> {
  List<dynamic>? _all;
  List<dynamic>? _centers;
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  String _typeFilter = 'all';
  String _campusName = '';

  static final DateFormat _storeFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayFormat = DateFormat('MMMM dd, yyyy');

  static DateTime? _parseDate(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String _formatDate(Object? value) {
    final date = _parseDate(value);
    if (date == null) return '';
    return _displayFormat.format(date);
  }

  static String _normalizeDate(Object? value) {
    final date = _parseDate(value);
    if (date == null) return '';
    return _storeFormat.format(date);
  }

  /// Days until [value]; negative if already past.
  static int _daysUntil(Object? value) {
    final date = _parseDate(value);
    if (date == null) return 9999;
    final today = DateTime.now();
    final diff = date.difference(DateTime(today.year, today.month, today.day));
    return diff.inDays;
  }

  /// Days until the next recurring audit date (annual from audit_date up to
  /// expiration_date). Returns 9999 if no audit dates are set.
  static int _nextAuditDays(Object? auditValue, Object? expValue) {
    final audit = _parseDate(auditValue);
    final exp = _parseDate(expValue);
    if (audit == null) return 9999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var next = audit;
    // Walk forward in yearly increments until we find a date >= today
    // or we pass the expiration date.
    while (next.isBefore(today)) {
      final candidate = DateTime(next.year + 1, next.month, next.day);
      if (exp != null && candidate.isAfter(exp)) break;
      next = candidate;
    }
    return next.difference(today).inDays;
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onChanged,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select a date',
        suffixIcon: controller.text.isEmpty
            ? const Icon(Icons.calendar_today, size: 18)
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear date',
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
      ),
      onTap: () async {
        final initial = _parseDate(controller.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked == null) return;
        controller.text = _storeFormat.format(picked);
        onChanged();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get('/centers');
      _all = res.data as List<dynamic>?;
      try {
        final campusRes = await ApiClient.get('/settings/DEFAULT_CAMPUS_NAME');
        _campusName = (campusRes.data['value'] as String?) ?? '';
      } catch (_) {}
      _applyFilters();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _search.text.trim().toLowerCase();
    var list = _all ?? [];
    if (_typeFilter != 'all') {
      list = list.where((c) => c['type']?.toString() == _typeFilter).toList();
    }
    if (query.isNotEmpty) {
      list = list.where((c) {
        final name = c['name']?.toString().toLowerCase() ?? '';
        final quals = (c['qualifications'] as List<dynamic>? ?? [])
            .join(', ')
            .toLowerCase();
        return name.contains(query) || quals.contains(query);
      }).toList();
    }
    setState(() => _centers = list);
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

  Future<void> _delete(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Center'),
        content: Text(
          'Delete ${c['name']}? Assessees or trainees linked to this center '
          'will also be removed.',
        ),
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
      await ApiClient.delete('/centers/${c['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Center deleted')),
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

  Future<void> _completeAudit(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Audit'),
        content: Text(
          'Mark audit as completed for ${c['name']}?\n\n'
          'This will record the current date and time as the audit completion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.post('/centers/${c['id']}/complete-audit');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audit marked as completed')),
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

  Future<void> _showReportDialog() async {
    final allColumns = {
      'name': 'Center Name',
      'accreditation_number': 'Accreditation No.',
      'type': 'Type',
      'status': 'Status',
      'address': 'Address',
      'fee': 'Fee',
      'qualifications': 'Qualifications',
      'expiration_date': 'Expiration',
      'audit_date': 'Audit Date',
    };
    final selected = <String>{};
    selected.addAll(allColumns.keys.take(4));

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Print Center Report'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select columns to include:'),
                const SizedBox(height: 8),
                ...allColumns.entries.map((e) {
                  final checked = selected.contains(e.key);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value),
                    value: checked,
                    onChanged: (v) {
                      setDialogState(() {
                        if (v == true) {
                          selected.add(e.key);
                        } else {
                          selected.remove(e.key);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      final list = (_centers ?? [])
                          .map((c) => c as Map<String, dynamic>)
                          .toList();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CenterReportPrintScreen(
                            centers: list,
                            selectedColumns: selected,
                            reportTitle: _typeFilter == 'assessment'
                                ? 'Assessment Center Report'
                                : _typeFilter == 'training'
                                    ? 'Training Center Report'
                                    : 'Center Report',
                          ),
                        ),
                      );
                    },
              child: const Text('Print'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForm([Map<String, dynamic>? center]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(
      text: center?['name']?.toString() ?? '',
    );
    final accreditationNumber = TextEditingController(
      text: center?['accreditation_number']?.toString() ?? '',
    );
    final address = TextEditingController(
      text: center?['address']?.toString() ?? '',
    );
    final assessmentFee = TextEditingController(
      text: (center?['assessment_fee'] as num?)?.toString() ?? '',
    );
    final trainingFee = TextEditingController(
      text: (center?['training_fee'] as num?)?.toString() ?? '',
    );
    final qualifications = TextEditingController(
      text: (center?['qualifications'] as List<dynamic>? ?? []).join(', '),
    );
    final expirationDate = TextEditingController(
      text: _normalizeDate(center?['expiration_date']),
    );
    final auditDate = TextEditingController(
      text: _normalizeDate(center?['audit_date']),
    );
    var type = center?['type']?.toString() ?? 'assessment';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(center == null ? 'Add Center' : 'Edit Center'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: 'Center Name',
                        helperText: _campusName.isNotEmpty
                            ? 'Campus: $_campusName'
                            : null,
                      ),
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
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'assessment',
                          child: Text('Assessment Center'),
                        ),
                        DropdownMenuItem(
                          value: 'training',
                          child: Text('Training Center'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => type = v ?? 'assessment'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    if (type == 'assessment')
                      TextFormField(
                        controller: assessmentFee,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Assessment Fee',
                          prefixText: '\u20B1 ',
                        ),
                      )
                    else
                      TextFormField(
                        controller: trainingFee,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Training Fee',
                          prefixText: '\u20B1 ',
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qualifications,
                      minLines: 3,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'TESDA Qualifications',
                        helperText: 'Separate each qualification with a comma',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _dateField(
                      controller: expirationDate,
                      label: 'Expiration Date',
                      onChanged: () {
                        final exp = _parseDate(expirationDate.text);
                        if (exp != null) {
                          final audit = DateTime(exp.year - 1, exp.month, exp.day);
                          auditDate.text = _storeFormat.format(audit);
                        } else {
                          auditDate.clear();
                        }
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: auditDate,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Audit Date (auto: 1 year before expiration)',
                        helperText: 'Recurs annually until expiration',
                      ),
                    ),
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
            _DialogSubmitButton(
              onSubmit: () async {
                if (!formKey.currentState!.validate()) return false;
                final payload = <String, dynamic>{
                  'name': name.text.trim(),
                  'accreditation_number': accreditationNumber.text.trim(),
                  'type': type,
                  'address': address.text.trim(),
                  'assessment_fee': double.tryParse(assessmentFee.text) ?? 0,
                  'training_fee': double.tryParse(trainingFee.text) ?? 0,
                  'qualifications': qualifications.text.trim(),
                  'expiration_date': expirationDate.text.trim().isEmpty
                      ? null
                      : expirationDate.text.trim(),
                  'audit_date': auditDate.text.trim().isEmpty
                      ? null
                      : auditDate.text.trim(),
                };
                try {
                  if (center == null) {
                    await ApiClient.post('/centers', data: payload);
                  } else {
                    await ApiClient.put('/centers/${center['id']}', data: payload);
                  }
                  if (!context.mounted) return false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Center saved')),
                  );
                  _load();
                  return true;
                } catch (e) {
                  if (!context.mounted) return false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: ${_friendlyError(e)}')),
                  );
                  return false;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final list = _centers ?? [];

    final expiring = <Map<String, dynamic>>[];
    for (final c in list) {
      final expDays = _daysUntil(c['expiration_date']);
      final auditDays = _nextAuditDays(c['audit_date'], c['expiration_date']);
      if (expDays <= 30) {
        expiring.add({
          'name': c['name']?.toString() ?? '',
          'field': 'Expiration',
          'days': expDays,
        });
      }
      if (auditDays <= 30) {
        expiring.add({
          'name': c['name']?.toString() ?? '',
          'field': 'Audit',
          'days': auditDays,
        });
      }
    }

    return Column(
      children: [
        if (expiring.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              border: const Border(
                left: BorderSide(color: AppTheme.warning, width: 3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Text(
                    expiring.map((e) {
                      final label = e['days'] as int < 0
                          ? '${e['field']} date for ${e['name']} has passed'
                          : '${e['field']} date for ${e['name']} in ${e['days']} days';
                      return label;
                    }).join('  |  '),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search center or qualification',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All types')),
                    DropdownMenuItem(
                      value: 'assessment',
                      child: Text('Assessment'),
                    ),
                    DropdownMenuItem(value: 'training', child: Text('Training')),
                  ],
                  onChanged: (v) {
                    setState(() => _typeFilter = v ?? 'all');
                    _applyFilters();
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add_business, size: 18),
                label: const Text('Add Center'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showReportDialog(),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print Report'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.business_outlined,
                  title: 'No centers yet',
                  subtitle: 'Add assessment or training centers to get started',
                )
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateColor.resolveWith(
                          (_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                      columns: const [
                        DataColumn(label: Text('Center Name')),
                        DataColumn(label: Text('Accreditation No.')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Address')),
                        DataColumn(label: Text('Fee')),
                        DataColumn(label: Text('Qualifications')),
                        DataColumn(label: Text('Expiration')),
                        DataColumn(label: Text('Audit')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: list.map<DataRow>((c) {
                        final type = c['type']?.toString() ?? '';
                        final fee = type == 'assessment'
                            ? (c['assessment_fee']?.toString() ?? '0')
                            : (c['training_fee']?.toString() ?? '0');
                        final quals =
                            (c['qualifications'] as List<dynamic>? ?? [])
                                .join(', ');
                        final expDays = _daysUntil(c['expiration_date']);
                        final auditDays = _nextAuditDays(c['audit_date'], c['expiration_date']);
                        final expText = _formatDate(c['expiration_date']);
                        final auditText = _formatDate(c['audit_date']);
                        final auditCompletedAt = c['audit_completed_at']?.toString();
                        final auditCompletedDate = auditCompletedAt != null && auditCompletedAt.isNotEmpty
                            ? DateTime.tryParse(auditCompletedAt)
                            : null;
                        final isPending = c['status'] == 'Pending';
                        return DataRow(
                          cells: [
                            DataCell(Text(c['name']?.toString() ?? '')),
                            DataCell(Text(c['accreditation_number']?.toString() ?? '')),
                            DataCell(Text(type == 'assessment'
                                ? 'Assessment'
                                : 'Training')),
                            DataCell(
                              c['status'] == 'Pending'
                                  ? StatusBadge.warning(c['status']?.toString() ?? 'Pending')
                                  : StatusBadge.success(c['status']?.toString() ?? 'Complete'),
                            ),
                            DataCell(Text(c['address']?.toString() ?? '')),
                            DataCell(Text('\u20B1$fee')),
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 240),
                                child: Text(
                                  quals.isEmpty ? 'None' : quals,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (expText.isNotEmpty && expDays <= 30)
                                  Icon(
                                    expDays < 0
                                        ? Icons.error_outline
                                        : Icons.warning_amber,
                                    size: 16,
                                    color: expDays < 0
                                        ? AppTheme.error
                                        : AppTheme.warning,
                                  ),
                                const SizedBox(width: 4),
                                Text(expText.isEmpty ? 'None' : expText),
                              ],
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (auditText.isNotEmpty && auditDays <= 30)
                                  Icon(
                                    auditDays < 0
                                        ? Icons.error_outline
                                        : Icons.warning_amber,
                                    size: 16,
                                    color: auditDays < 0
                                        ? AppTheme.error
                                        : AppTheme.warning,
                                  ),
                                const SizedBox(width: 4),
                                if (auditCompletedDate != null)
                                  StatusBadge.success(
                                    'Audited ${DateFormat('MMMM dd, yyyy hh:mm a').format(auditCompletedDate)}',
                                  )
                                else
                                  Text(auditText.isEmpty ? 'None' : auditText),
                              ],
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPending && auditCompletedDate == null)
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline,
                                        size: 20, color: AppTheme.success),
                                    tooltip: 'Complete Audit',
                                    onPressed: () => _completeAudit(c),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit',
                                  onPressed: () => _showForm(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: AppTheme.error),
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(c),
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

class _DialogSubmitButton extends StatefulWidget {
  final Future<bool> Function() onSubmit;

  const _DialogSubmitButton({required this.onSubmit});

  @override
  State<_DialogSubmitButton> createState() => _DialogSubmitButtonState();
}

class _DialogSubmitButtonState extends State<_DialogSubmitButton> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _submitting
          ? null
          : () async {
              setState(() => _submitting = true);
              final ok = await widget.onSubmit();
              if (mounted) setState(() => _submitting = false);
              if (ok && context.mounted) Navigator.of(context).pop();
            },
      child: _submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Save'),
    );
  }
}
