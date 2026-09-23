import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
import '../widgets/ui_components.dart';

class AssessorFeeLetterScreen extends StatefulWidget {
  const AssessorFeeLetterScreen({super.key});

  @override
  State<AssessorFeeLetterScreen> createState() =>
      _AssessorFeeLetterScreenState();
}

class _AssessorFeeLetterScreenState extends State<AssessorFeeLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _dateController = TextEditingController();
  final _toController = TextEditingController();
  final _fromController = TextEditingController();
  final _subjectController = TextEditingController();
  final _assessmentDateFromController = TextEditingController();
  final _assessmentDateToController = TextEditingController();
  final _feePerAssesseeController = TextEditingController();
  final _bodyController = TextEditingController();
  final _footerBodyController = TextEditingController();
  List<Map<String, dynamic>> _tableRows = [];
  List<String> _availableQualifications = [];
  String? _selectedQualification;
  List<dynamic>? _users;
  String? _selectedUserId;
  List<String> _selectedDesignations = [];
  bool _loading = true;
  bool _generating = false;

  static final DateFormat _displayFormat = DateFormat('MMMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _dateController.text = _displayFormat.format(DateTime.now());
    _subjectController.text = "Request for Assessor's Fee";
    _bodyController.text =
        'This is to respectfully request the processing of assessor fees based on the number of candidates assessed as reflected in the table below.';
    _footerBodyController.text =
        'Hoping for your favorable action on this matter. Thank you very much.';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final codeRes = await ApiClient.get(
        '/document-types/${AppConstants.internalSlug}/next-code',
      );
      final usersRes = await ApiClient.get('/users');
      final data = codeRes.data as Map<String, dynamic>;
      _codeController.text = (data['code'] as String?) ?? '';
      if (!mounted) return;
      setState(() {
        _users = usersRes.data as List<dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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

  String _dateRangeLabel() {
    final fromStr = _assessmentDateFromController.text.trim();
    final toStr = _assessmentDateToController.text.trim();
    if (fromStr.isEmpty && toStr.isEmpty) return '';
    if (fromStr.isEmpty) return toStr;
    if (toStr.isEmpty) return fromStr;

    final from = _displayFormat.tryParse(fromStr);
    final to = _displayFormat.tryParse(toStr);
    if (from == null || to == null) return '$fromStr - $toStr';

    // Single day assessment: just "MMMM dd, yyyy"
    if (from.year == to.year && from.month == to.month && from.day == to.day) {
      return _displayFormat.format(from);
    }
    // Two or more days: use range format
    if (from.year == to.year && from.month == to.month) {
      return '${_displayFormat.format(from).replaceAll(', ${from.year}', '')}-${to.day}, ${to.year}';
    }
    if (from.year == to.year) {
      final monthDayFrom = DateFormat('MMMM d').format(from);
      final monthDayTo = DateFormat('MMMM d').format(to);
      return '$monthDayFrom - $monthDayTo, ${to.year}';
    }
    return '$fromStr - $toStr';
  }

  Future<void> _generateTable() async {
    final feePerAssessee =
        double.tryParse(_feePerAssesseeController.text) ?? 0.0;

    setState(() => _generating = true);
    try {
      // Total assessee count — not filtered by assessment date.
      final res = await ApiClient.get('/assessees?type=assessment');
      final assessees =
          (res.data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final groups = <String, Map<String, dynamic>>{};
      final qualifications = <String>{};

      for (final a in assessees) {
        final competency = a['competency']?.toString().toLowerCase() ?? '';
        if (competency == 'absent') continue;

        final name = a['assessor']?.toString() ?? 'Unassigned';
        final qualification = a['qualification']?.toString() ?? 'N/A';
        qualifications.add(qualification);
        if (_selectedQualification != null &&
            _selectedQualification != 'All' &&
            qualification != _selectedQualification) {
          continue;
        }
        final key = '$name|$qualification';
        if (!groups.containsKey(key)) {
          groups[key] = {
            'Assessor': name,
            'Qualification': qualification,
            'Date of Assessment': _dateRangeLabel(),
            'No. of Assessed Candidates': 0,
            "Assessor's Fee": 0.0,
          };
        }
        groups[key]!['No. of Assessed Candidates'] =
            (groups[key]!['No. of Assessed Candidates'] as int) + 1;
        groups[key]!["Assessor's Fee"] =
            (groups[key]!["Assessor's Fee"] as double) + feePerAssessee;
      }

      setState(() {
        _tableRows = groups.values.toList()
          ..sort((a, b) => a['Assessor']
              .toString()
              .compareTo(b['Assessor'].toString()));
        _availableQualifications = qualifications.toList()..sort();
        _generating = false;
      });
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _dateController.dispose();
    _toController.dispose();
    _fromController.dispose();
    _subjectController.dispose();
    _assessmentDateFromController.dispose();
    _assessmentDateToController.dispose();
    _feePerAssesseeController.dispose();
    _bodyController.dispose();
    _footerBodyController.dispose();
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
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UniversityLetterhead(),
                    const SizedBox(height: AppTheme.spaceMd),
                    const SectionHeader(
                      icon: Icons.table_chart,
                      imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                      title: "Assessor's Fee",
                      subtitle: 'Generate and save the assessor fee letter',
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
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: () => _pickDate(_dateController),
                        decoration: InputDecoration(
                          labelText: 'Date',
                          isDense: true,
                          prefixIcon: const Icon(Icons.calendar_today, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            onPressed: () => _pickDate(_dateController),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _assessmentDateFromController,
                            readOnly: true,
                            onTap: () =>
                                _pickDate(_assessmentDateFromController),
                            decoration: InputDecoration(
                              labelText: 'Assessment Date From (optional)',
                              isDense: true,
                              prefixIcon: const Icon(Icons.event, size: 18),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.edit_calendar, size: 18),
                                onPressed: () =>
                                    _pickDate(_assessmentDateFromController),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          child: TextFormField(
                            controller: _assessmentDateToController,
                            readOnly: true,
                            onTap: () =>
                                _pickDate(_assessmentDateToController),
                            decoration: InputDecoration(
                              labelText: 'Assessment Date To (optional)',
                              isDense: true,
                              prefixIcon: const Icon(Icons.event, size: 18),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.edit_calendar, size: 18),
                                onPressed: () =>
                                    _pickDate(_assessmentDateToController),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _feePerAssesseeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Assessor's Fee per Assessee",
                              prefixText: '\u20B1 ',
                              isDense: true,
                              helperText:
                                  'Multiplied by no. of non-absent candidates',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        FilledButton.icon(
                          onPressed: _generating ? null : _generateTable,
                          icon: _generating
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: const Text('Generate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
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
                    ],
                    const SizedBox(height: AppTheme.spaceMd),
                    TextFormField(
                      controller: _toController,
                      decoration: const InputDecoration(
                        labelText: 'To (Name, Designation, Office, Address)',
                        hintText:
                            'e.g. Juan Dela Cruz, Program Coordinator, TVET Office, Carig Campus, Tuguegarao City',
                      ),
                      minLines: 1,
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    TextFormField(
                      controller: _fromController,
                      decoration:
                          const InputDecoration(labelText: 'Thru (Office)'),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    TextFormField(
                      controller: _subjectController,
                      decoration:
                          const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        labelText: 'Body (Introduction)',
                        hintText: 'Introductory paragraph before the table',
                      ),
                      minLines: 3,
                      maxLines: 6,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Table section with styled header
                    const SectionHeader(
                      icon: Icons.table_chart,
                      imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                      title: 'Assessor Fee Summary Table',
                      subtitle: 'Generate the fee table from assessment records',
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    if (_availableQualifications.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedQualification ?? 'All',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Qualification',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: 'All', child: Text('All')),
                          ..._availableQualifications.map((q) =>
                              DropdownMenuItem(
                                  value: q,
                                  child: Text(q,
                                      overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedQualification = v;
                          });
                          _generateTable();
                        },
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateColor.resolveWith((_) =>
                            AppTheme.csuMaroon.withValues(alpha: 0.06)),
                        columns: const [
                          DataColumn(label: Text('Assessor')),
                          DataColumn(label: Text('Qualification')),
                          DataColumn(label: Text('Date of Assessment')),
                          DataColumn(label: Text('No. Assessed')),
                          DataColumn(label: Text("Assessor's Fee")),
                        ],
                        rows: [
                          ..._tableRows.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row['Assessor'].toString())),
                                DataCell(Text(row['Qualification'].toString())),
                                DataCell(Text(row['Date of Assessment'].toString())),
                                DataCell(Text(row['No. of Assessed Candidates'].toString())),
                                DataCell(Text('\u20B1${(row["Assessor's Fee"] as double).toStringAsFixed(2)}')),
                              ],
                            );
                          }),
                          DataRow(
                            color: WidgetStateColor.resolveWith(
                                (_) => AppTheme.csuMaroon.withValues(alpha: 0.05)),
                            cells: [
                              const DataCell(Text('TOTAL',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              DataCell(Text(
                                _tableRows.isEmpty
                                    ? '0'
                                    : _tableRows
                                        .map((r) =>
                                            r['No. of Assessed Candidates'] as int)
                                        .reduce((a, b) => a + b)
                                        .toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )),
                              DataCell(Text(
                                '\u20B1${_tableRows.isEmpty ? '0.00' : _tableRows.map((r) => r["Assessor's Fee"] as double).reduce((a, b) => a + b).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_tableRows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                        child: Text(
                          'Press Generate to populate the table with all assessees.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: AppTheme.spaceLg),
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
