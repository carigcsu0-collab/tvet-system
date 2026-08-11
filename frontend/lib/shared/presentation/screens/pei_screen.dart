import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
import '../../../core/records_refresh.dart';
import '../widgets/ui_components.dart';
import 'pei_print_screen.dart';

/// Entry screen for the TESDA "Performance Evaluation Instrument" (PEI).
/// Contains two forms: F29 (by Candidate) and F30 (by AC Manager).
/// Header fields, final ratings, and evaluator remarks are captured;
/// the 1-5 rating tables are left blank for manual filling.
class PeiScreen extends StatefulWidget {
  const PeiScreen({super.key});

  @override
  State<PeiScreen> createState() => _PeiScreenState();
}

class _PeiScreenState extends State<PeiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _dateController = TextEditingController();
  final _assessorNameController = TextEditingController();
  // Form 1 (Candidate)
  final _respondentName1Controller = TextEditingController();
  final _dateAccomplished1Controller = TextEditingController();
  final _finalRating1Controller = TextEditingController();
  final _evaluatorRemarks1Controller = TextEditingController();
  // Form 2 (AC Manager)
  final _respondentName2Controller = TextEditingController();
  final _dateAccomplished2Controller = TextEditingController();
  final _finalRating2Controller = TextEditingController();
  final _evaluatorRemarks2Controller = TextEditingController();

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
        ApiClient.get('/document-types/${AppConstants.peiSlug}/next-code'),
        ApiClient.get('/assessors'),
      ]);
      final codeData = results[0].data as Map<String, dynamic>;
      _codeController.text = (codeData['code'] as String?) ?? '';

      final assessors = results[1].data as List<dynamic>? ?? [];
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


  void _onQualificationChanged(String? qual) {
    setState(() {
      _selectedQualification = qual;
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
    setState(() => controller.text = _displayFormat.format(picked));
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
        'assessorName': _assessorNameController.text.trim(),
        'qualification': _selectedQualification ?? '',
        'respondentName1': _respondentName1Controller.text.trim(),
        'dateAccomplished1': _dateAccomplished1Controller.text.trim(),
        'finalRating1': _finalRating1Controller.text.trim(),
        'evaluatorRemarks1': _evaluatorRemarks1Controller.text.trim(),
        'respondentName2': _respondentName2Controller.text.trim(),
        'dateAccomplished2': _dateAccomplished2Controller.text.trim(),
        'finalRating2': _finalRating2Controller.text.trim(),
        'evaluatorRemarks2': _evaluatorRemarks2Controller.text.trim(),
        'date': _dateController.text.trim(),
      };
      final res = await ApiClient.post(
        '/documents/${AppConstants.peiSlug}/generate',
        data: payload,
      );
      setState(() => _generated = res.data as Map<String, dynamic>);
      recordsRefresh.refresh();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PEI document saved')),
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
    _assessorNameController.dispose();
    _respondentName1Controller.dispose();
    _dateAccomplished1Controller.dispose();
    _finalRating1Controller.dispose();
    _evaluatorRemarks1Controller.dispose();
    _respondentName2Controller.dispose();
    _dateAccomplished2Controller.dispose();
    _finalRating2Controller.dispose();
    _evaluatorRemarks2Controller.dispose();
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
                      icon: Icons.rate_review_outlined,
                      imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                      title: 'Performance Evaluation Instrument',
                      subtitle:
                          'TESDA-OP-CO-04-F29 (Candidate) & F30 (AC Manager)',
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
                        labelText: 'Qualification',
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

                    // Shared assessor fields
                    if (_assessors != null && _assessors!.isNotEmpty) ...[
                      Builder(builder: (context) {
                        final assessorOptions =
                            _assessorsForQualification(_selectedQualification);
                        return DropdownButtonFormField<String?>(
                          initialValue: assessorOptions.any(
                                  (a) => a['id']?.toString() == _selectedAssessorId)
                              ? _selectedAssessorId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Competency Assessor (evaluated)',
                            isDense: true,
                            prefixIcon: Icon(Icons.person, size: 18),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('— Select assessor —')),
                            ...assessorOptions.map((a) {
                              final name = a['name']?.toString() ?? '';
                              final accred =
                                  a['accreditation_number']?.toString() ?? '';
                              final label =
                                  accred.isEmpty ? name : '$name ($accred)';
                              return DropdownMenuItem<String?>(
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
                        labelText: "Assessor's Name",
                        isDense: true,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceXl),

                    // Form 1: By Candidate (F29)
                    _buildFormSection(
                      title: 'Form 1 — By Candidate (F29)',
                      respondentController: _respondentName1Controller,
                      dateController: _dateAccomplished1Controller,
                      finalRatingController: _finalRating1Controller,
                      remarksController: _evaluatorRemarks1Controller,
                    ),
                    const SizedBox(height: AppTheme.spaceXl),

                    // Form 2: By AC Manager (F30)
                    _buildFormSection(
                      title: 'Form 2 — By AC Manager (F30)',
                      respondentController: _respondentName2Controller,
                      dateController: _dateAccomplished2Controller,
                      finalRatingController: _finalRating2Controller,
                      remarksController: _evaluatorRemarks2Controller,
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
                                    strokeWidth: 2, color: Colors.white),
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

  Widget _buildFormSection({
    required String title,
    required TextEditingController respondentController,
    required TextEditingController dateController,
    required TextEditingController finalRatingController,
    required TextEditingController remarksController,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.csuMaroon.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.csuMaroon.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppTheme.spaceMd),
          TextFormField(
            controller: respondentController,
            decoration: const InputDecoration(
              labelText: 'Name of Respondent',
              isDense: true,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date Accomplished',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.event, size: 18),
                      onPressed: () => _pickDate(dateController),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: finalRatingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Final Rating',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          TextFormField(
            controller: remarksController,
            decoration: const InputDecoration(
              labelText: "Evaluator's Remarks (FOR TESDA USE ONLY)",
              isDense: true,
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
        ],
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
        border: Border.all(color: AppTheme.csuMaroon.withValues(alpha: 0.15)),
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
                  builder: (_) => PeiPrintScreen(code: code),
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
