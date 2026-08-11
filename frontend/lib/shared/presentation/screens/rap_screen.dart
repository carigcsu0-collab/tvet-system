import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
import '../../../core/records_refresh.dart';
import '../widgets/ui_components.dart';
import 'rap_print_screen.dart';

/// Entry screen for the TESDA "Report on Assessment Proceedings" (RAP) form.
/// Captures the header fields + narrative; the 12-item findings table is left
/// blank for manual filling on the printed form.
class RapScreen extends StatefulWidget {
  const RapScreen({super.key});

  @override
  State<RapScreen> createState() => _RapScreenState();
}

class _RapScreenState extends State<RapScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _dateController = TextEditingController();
  final _accreditationNumberController = TextEditingController();
  final _assessmentDateController = TextEditingController();
  final _assessorNameController = TextEditingController();

  List<dynamic>? _centers;
  List<String> _qualifications = [];
  List<dynamic>? _assessors;
  String? _selectedQualification;
  String? _selectedAssessorId;
  final DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _generated;

  static final DateFormat _displayFormat = DateFormat('MMMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _dateController.text = _displayFormat.format(_date);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/document-types/${AppConstants.rapSlug}/next-code'),
        ApiClient.get('/centers'),
        ApiClient.get('/assessors'),
      ]);
      final codeData = results[0].data as Map<String, dynamic>;
      _codeController.text = (codeData['code'] as String?) ?? '';

      final centers = results[1].data as List<dynamic>? ?? [];
      final assessors = results[2].data as List<dynamic>? ?? [];
      // Aggregate all qualifications from all assessors
      final qualSet = <String>{};
      for (final a in assessors) {
        if (a is! Map) continue;
        final quals = a['qualifications'] as List<dynamic>? ?? [];
        for (final q in quals) {
          qualSet.add(q.toString());
        }
      }
      if (!mounted) return;
      setState(() {
        _centers = centers;
        _qualifications = qualSet.toList()..sort();
        _assessors = assessors;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _assessorsForQualification(String? qualification) {
    final all = (_assessors ?? []).whereType<Map>().map((a) {
      final map = <String, dynamic>{};
      for (final entry in a.entries) {
        map[entry.key.toString()] = entry.value;
      }
      return map;
    }).toList();

    if (qualification == null || qualification.trim().isEmpty) {
      all.sort((a, b) =>
          (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
      return all;
    }

    final filtered = all.where((a) {
      final quals = (a['qualifications'] as List<dynamic>? ?? [])
          .map((q) => q.toString().trim())
          .toSet();
      return quals.contains(qualification.trim());
    }).toList();
    filtered.sort((a, b) =>
        (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    return filtered;
  }

  String _accreditationForQualification(String? qualification) {
    if (qualification == null || qualification.trim().isEmpty) return '';
    for (final c in _centers ?? []) {
      if (c is! Map) continue;
      final quals = (c['qualifications'] as List<dynamic>? ?? [])
          .map((q) => q.toString().trim())
          .toSet();
      if (quals.contains(qualification.trim())) {
        return c['accreditation_number']?.toString() ?? '';
      }
    }
    return '';
  }

  void _onQualificationChanged(String? qual) {
    setState(() {
      _selectedQualification = qual;
      _accreditationNumberController.text = _accreditationForQualification(qual);
      final availableAssessors = _assessorsForQualification(qual);
      final selected = availableAssessors.where(
        (a) => a['id']?.toString() == _selectedAssessorId,
      );
      if (selected.isEmpty) {
        _selectedAssessorId = null;
        _assessorNameController.clear();
      }
    });
  }

  void _onAssessorChanged(String? assessorId) {
    if (assessorId == null) return;
    final assessor = _assessors?.firstWhere(
      (a) => a['id']?.toString() == assessorId,
      orElse: () => <String, dynamic>{},
    );
    if (assessor == null || assessor is! Map) return;
    setState(() {
      _selectedAssessorId = assessorId;
      _assessorNameController.text = assessor['name']?.toString() ?? '';
      final quals = (assessor['qualifications'] as List<dynamic>? ?? [])
          .map((q) => q.toString())
          .where((q) => q.trim().isNotEmpty)
          .toList();
      if (_selectedQualification == null ||
          !quals.contains(_selectedQualification)) {
        _selectedQualification = quals.isEmpty ? null : quals.first;
      }
      _accreditationNumberController.text =
          _accreditationForQualification(_selectedQualification);
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      controller.text = _displayFormat.format(picked);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedQualification == null || _selectedQualification!.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a qualification')),
        );
      }
      return;
    }
    if (_selectedAssessorId == null || _selectedAssessorId!.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a competency assessor')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    final recordsRefresh = context.read<RecordsRefresh>();
    try {
      final payload = <String, dynamic>{
        'assessorId': _selectedAssessorId,
        'accreditationNumber': _accreditationNumberController.text.trim(),
        'qualificationTitle': _selectedQualification ?? '',
        'qualification': _selectedQualification ?? '',
        'assessmentDate': _assessmentDateController.text.trim(),
        'assessorName': _assessorNameController.text.trim(),
        'date': _dateController.text.trim(),
      };
      final res = await ApiClient.post(
        '/documents/${AppConstants.rapSlug}/generate',
        data: payload,
      );
      setState(() => _generated = res.data as Map<String, dynamic>);
      recordsRefresh.refresh();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RAP document saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _dateController.dispose();
    _accreditationNumberController.dispose();
    _assessmentDateController.dispose();
    _assessorNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      icon: Icons.fact_check_outlined,
                      imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                      title: 'Report on Assessment Proceedings',
                      subtitle:
                          'TESDA-OP-CO-05-F34 — header fields and narrative',
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
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
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date',
                          isDense: true,
                          prefixIcon: const Icon(Icons.calendar_today, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.event, size: 18),
                            onPressed: () => _pickDate(_dateController),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Qualification dropdown (aggregated from all centers)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedQualification,
                      decoration: const InputDecoration(
                        labelText: 'Title of Qualification',
                        isDense: true,
                        prefixIcon: Icon(Icons.school, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— Select qualification —')),
                        ..._qualifications.map((q) => DropdownMenuItem(
                              value: q,
                              child: Text(q),
                            )),
                      ],
                      onChanged: _onQualificationChanged,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    TextFormField(
                      controller: _accreditationNumberController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Accreditation Number (auto-filled)',
                        isDense: true,
                        prefixIcon: Icon(Icons.badge, size: 18),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    TextFormField(
                      controller: _assessmentDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date of Assessment',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.event, size: 18),
                          onPressed: () => _pickDate(_assessmentDateController),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Assessor picker
                    if (_assessors != null && _assessors!.isNotEmpty) ...[
                      Builder(builder: (context) {
                        final assessorOptions =
                            _assessorsForQualification(_selectedQualification);
                        return DropdownButtonFormField<String>(
                          initialValue: assessorOptions.any(
                                  (a) => a['id']?.toString() == _selectedAssessorId)
                              ? _selectedAssessorId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Competency Assessor',
                            isDense: true,
                            prefixIcon: Icon(Icons.person, size: 18),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('— Select assessor —')),
                            ...assessorOptions.map((a) {
                              final name = a['name']?.toString() ?? '';
                              final accred =
                                  a['accreditation_number']?.toString() ?? '';
                              final label =
                                  accred.isEmpty ? name : '$name ($accred)';
                              return DropdownMenuItem(
                                value: a['id']?.toString(),
                                child: Text(label),
                              );
                            }),
                          ],
                          onChanged: _onAssessorChanged,
                        );
                      }),
                      const SizedBox(height: AppTheme.spaceMd),
                    ],
                    TextFormField(
                      controller: _assessorNameController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Name of Competency Assessor',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXl),
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
                        label: Text(_saving ? 'Saving...' : 'Save Document'),
                      ),
                    ),
                    if (_generated != null) ...[
                      const SizedBox(height: AppTheme.spaceLg),
                      _buildSavedPanel(),
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

  Widget _buildSavedPanel() {
    final code = _generated!['code']?.toString() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.csuMaroon.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border:
            Border.all(color: AppTheme.csuMaroon.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text('Saved: $code',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RapPrintScreen(code: code),
                ),
              );
            },
            icon: Icon(Icons.print,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.csuGoldLight
                    : AppTheme.success),
            label: Text(
              'Print / View',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.csuGoldLight
                    : AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
