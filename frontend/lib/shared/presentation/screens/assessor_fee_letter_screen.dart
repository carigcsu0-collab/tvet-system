import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
import '../widgets/ui_components.dart';
import 'print_preview_screen.dart';

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
  String? _coordinator;
  final String _coordinatorTitle = 'Campus TVET Coordinator';
  List<dynamic>? _users;
  String? _selectedUserId;
  List<String> _selectedDesignations = [];
  bool _loading = true;
  bool _generating = false;
  bool _saving = false;
  Map<String, dynamic>? _generated;
  final _officeController = TextEditingController();
  final _specialOrderNumberController = TextEditingController();
  final _specialOrderDateController = TextEditingController();
  bool _updatingStatus = false;

  static final DateFormat _displayFormat = DateFormat('MMMM dd, yyyy');
  static final DateFormat _storeFormat = DateFormat('yyyy-MM-dd');

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

  String _displayToStore(String display) {
    final dt = _displayFormat.tryParse(display.trim());
    if (dt != null) return _storeFormat.format(dt);
    return display.trim();
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
    final fromDate = _displayToStore(_assessmentDateFromController.text);
    final toDate = _displayToStore(_assessmentDateToController.text);
    final feePerAssessee =
        double.tryParse(_feePerAssesseeController.text) ?? 0.0;

    if (fromDate.isEmpty && toDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one date')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      var url = '/assessees?';
      if (fromDate.isNotEmpty) url += 'assessment_date_from=$fromDate&';
      if (toDate.isNotEmpty) url += 'assessment_date_to=$toDate&';
      final res = await ApiClient.get(url);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'to': _toController.text.trim(),
        'from': _fromController.text.trim(),
        'subject': _subjectController.text.trim(),
        'date': _dateController.text.trim(),
        'assessment_date': _dateRangeLabel(),
        'fee_per_assessee': _feePerAssesseeController.text.trim(),
        'body': _bodyController.text.trim(),
        'footer_body': _footerBodyController.text.trim(),
        'table': _tableRows,
        'coordinatorName': _selectedSignatoryName.isNotEmpty
            ? _selectedSignatoryName
            : (_coordinator ?? ''),
        'coordinatorTitle': _selectedSignatoryName.isNotEmpty
            ? _selectedDesignations.join(', ')
            : _coordinatorTitle,
      };
      final res = await ApiClient.post(
        '/documents/${AppConstants.internalSlug}',
        data: payload,
      );
      setState(() => _generated = res.data as Map<String, dynamic>);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Assessor fee saved')));
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

  Future<void> _updateStatus(String newStatus) async {
    if (_generated == null) return;
    final code = _generated!['code']?.toString() ?? '';
    if (code.isEmpty) return;
    setState(() => _updatingStatus = true);
    try {
      final data = <String, dynamic>{
        'status': newStatus,
        if (newStatus == 'received') 'received_by_office': _officeController.text.trim(),
        if (newStatus == 'special_order') ...{
          'special_order_number': _specialOrderNumberController.text.trim(),
          'special_order_date': _specialOrderDateController.text.trim(),
        },
        if (newStatus == 'voucher_received') 'voucher_received': true,
      };
      final res = await ApiClient.put('/documents/$code/status', data: data);
      setState(() {
        _generated = res.data as Map<String, dynamic>;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to: $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      setState(() => _updatingStatus = false);
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
    _officeController.dispose();
    _specialOrderNumberController.dispose();
    _specialOrderDateController.dispose();
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
                              labelText: 'Assessment Date From',
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
                              labelText: 'Assessment Date To',
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
                          'Select an assessment date and press Generate to populate the table.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Footer body section
                    const SectionHeader(
                      icon: Icons.edit_note,
                      imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                      title: 'Closing Remarks (Optional)',
                      subtitle: 'Additional content after the fee table',
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    TextFormField(
                      controller: _footerBodyController,
                      decoration: const InputDecoration(
                        labelText: 'Footer Body',
                        hintText: 'Closing paragraph after the table',
                      ),
                      minLines: 3,
                      maxLines: 6,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
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
                      _buildStatusWorkflow(),
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

  Widget _buildStatusWorkflow() {
    final status = _generated!['status']?.toString() ?? 'saved';
    final receivedAt = _generated!['received_at']?.toString() ?? '';
    final receivedByOffice = _generated!['received_by_office']?.toString() ?? '';
    final specialOrderNumber = _generated!['special_order_number']?.toString() ?? '';
    final specialOrderDate = _generated!['special_order_date']?.toString() ?? '';
    final voucherReceived = _generated!['voucher_received'] == true;

    final statusLabels = {
      'saved': 'Saved',
      'received': 'Received',
      'special_order': 'Special Order',
      'voucher_received': 'Voucher Received',
    };

    final statusBadgeMap = {
      'saved': StatusBadge.info(statusLabels['saved']!),
      'received': StatusBadge.warning(statusLabels['received']!),
      'special_order': StatusBadge.info(statusLabels['special_order']!),
      'voucher_received': StatusBadge.success(statusLabels['voucher_received']!),
    };

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
          // Code + status badge
          Row(
            children: [
              Text(
                'Saved: ${_generated!['code']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              statusBadgeMap[status] ?? StatusBadge.info(status),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  final code = _generated!['code']?.toString() ?? '';
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PrintPreviewScreen(code: code),
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
          const Divider(),

          // Received info
          if (receivedAt.isNotEmpty) ...[
            Text(
              'Received by: ${receivedByOffice.isEmpty ? "N/A" : receivedByOffice}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Received at: $receivedAt',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: AppTheme.spaceSm),
          ],

          // Special order info
          if (specialOrderNumber.isNotEmpty || specialOrderDate.isNotEmpty) ...[
            Text(
              'Special Order: $specialOrderNumber',
              style: const TextStyle(fontSize: 13),
            ),
            if (specialOrderDate.isNotEmpty)
              Text(
                'Special Order Date: $specialOrderDate',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            const SizedBox(height: AppTheme.spaceSm),
          ],

          // Voucher checkbox
          if (status == 'special_order' || voucherReceived) ...[
            CheckboxListTile(
              value: voucherReceived,
              onChanged: _updatingStatus
                  ? null
                  : (v) {
                      if (v == true) {
                        _updateStatus('voucher_received');
                      }
                    },
              title: const Text('Received with Voucher'),
              subtitle: voucherReceived
                  ? const Text('Voucher has been received', style: TextStyle(fontSize: 12))
                  : const Text('Check when voucher is received', style: TextStyle(fontSize: 12)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppTheme.spaceSm),
          ],

          // Action buttons based on status
          if (status == 'saved') ...[
            const Text('Mark as Received:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spaceSm),
            TextFormField(
              controller: _officeController,
              decoration: const InputDecoration(
                labelText: 'Received by Office',
                isDense: true,
                helperText: 'Which office received this document',
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            FilledButton.icon(
              onPressed: _updatingStatus ? null : () => _updateStatus('received'),
              icon: const Icon(Icons.mark_email_read, size: 18),
              label: const Text('Mark Received'),
            ),
          ],

          if (status == 'received') ...[
            const Text('Add Special Order:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spaceSm),
            TextFormField(
              controller: _specialOrderNumberController,
              decoration: const InputDecoration(
                labelText: 'Special Order Number',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            TextFormField(
              controller: _specialOrderDateController,
              readOnly: true,
              onTap: () => _pickDate(_specialOrderDateController),
              decoration: InputDecoration(
                labelText: 'Special Order Date',
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  onPressed: () => _pickDate(_specialOrderDateController),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            FilledButton.icon(
              onPressed: _updatingStatus ? null : () => _updateStatus('special_order'),
              icon: const Icon(Icons.assignment_turned_in, size: 18),
              label: const Text('Submit Special Order'),
            ),
          ],

          if (_updatingStatus)
            const Padding(
              padding: EdgeInsets.only(top: AppTheme.spaceSm),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
