import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
import '../../../core/records_refresh.dart';
import '../widgets/ui_components.dart';
import 'print_preview_screen.dart';

class CertificateOfAppearanceScreen extends StatefulWidget {
  const CertificateOfAppearanceScreen({super.key});

  @override
  State<CertificateOfAppearanceScreen> createState() =>
      _CertificateOfAppearanceScreenState();
}

class _CertificateOfAppearanceScreenState
    extends State<CertificateOfAppearanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _officeController = TextEditingController();
  final _campusController = TextEditingController();
  final _dateController = TextEditingController();
  final _purposeController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthYearController = TextEditingController();
  final _issuedAtController = TextEditingController();
  final _coordinatorController = TextEditingController();
  final _codeController = TextEditingController();
  List<dynamic>? _users;
  String? _selectedUserId;
  List<String> _selectedDesignations = [];
  bool _loading = true;
  bool _generating = false;
  Map<String, dynamic>? _generated;
  String _coordinatorTitle = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiClient.get(
            '/document-types/${AppConstants.certificateSlug}/next-code'),
        ApiClient.get('/users'),
        ApiClient.get('/settings/DEFAULT_CAMPUS_NAME'),
        ApiClient.get('/settings/DEFAULT_ISSUED_AT'),
        ApiClient.get('/settings/DEFAULT_COORDINATOR_NAME'),
        ApiClient.get('/settings/DEFAULT_COORDINATOR_TITLE'),
      ]);
      _campusController.text =
          (results[2].data['value'] as String?) ?? '';
      _issuedAtController.text =
          (results[3].data['value'] as String?) ?? '';
      _codeController.text = (results[0].data['code'] as String?) ?? '';
      final coordName = results[4].data['value'] as String?;
      final coordTitle = results[5].data['value'] as String?;
      if (coordName != null && coordName.isNotEmpty) {
        _coordinatorController.text = coordName;
      }
      if (!mounted) return;
      setState(() {
        _users = results[1].data as List<dynamic>?;
        if (coordTitle != null && coordTitle.isNotEmpty) {
          _coordinatorTitle = coordTitle;
        }
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
    if (_selectedUserId == null) return _coordinatorController.text.trim();
    final u = _users?.firstWhere(
      (e) => e['id']?.toString() == _selectedUserId,
      orElse: () => <String, dynamic>{},
    );
    if (u == null) return '';
    final name = u['name']?.toString() ?? '';
    final ext = u['extension_name']?.toString() ?? '';
    return ext.isNotEmpty ? '$name $ext' : name;
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _generating = true);
    final recordsRefresh = context.read<RecordsRefresh>();
    try {
      final payload = {
        'recipient_name': _nameController.text.trim(),
        'recipient_office': _officeController.text.trim(),
        'campus_name': _campusController.text.trim(),
        'appearance_date': _dateController.text.trim(),
        'purpose': _purposeController.text.trim(),
        'issued_day': _dayController.text.trim(),
        'issued_month_year': _monthYearController.text.trim(),
        'issued_at': _issuedAtController.text.trim(),
        'coordinatorName': _selectedSignatoryName.isNotEmpty
            ? _selectedSignatoryName
            : _coordinatorController.text.trim(),
        'coordinatorTitle': _selectedSignatoryName.isNotEmpty
            ? (_selectedDesignations.isNotEmpty
                ? _selectedDesignations.join(', ')
                : _designationsFor(_selectedUserId).join(', '))
            : _coordinatorTitle,
      };
      final res = await ApiClient.post(
        '/documents/${AppConstants.certificateSlug}',
        data: payload,
      );
      setState(() => _generated = res.data as Map<String, dynamic>);
      recordsRefresh.refresh();
      _loadData();
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _officeController.dispose();
    _campusController.dispose();
    _dateController.dispose();
    _purposeController.dispose();
    _dayController.dispose();
    _monthYearController.dispose();
    _issuedAtController.dispose();
    _coordinatorController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  InputDecoration _underlineDecoration(String hint) => InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        border: const UnderlineInputBorder(),
        enabledBorder: const UnderlineInputBorder(),
        focusedBorder: const UnderlineInputBorder(),
      );

  Widget _underlineField(TextEditingController controller, String hint,
          {double width = 180, bool centered = false}) {
    final contentWidth = controller.text.isEmpty
        ? width
        : (controller.text.length * 8.0 + 32).clamp(width, 320.0);
    return SizedBox(
      width: contentWidth,
      child: TextFormField(
        controller: controller,
        decoration: _underlineDecoration(hint),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        maxLines: 1,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        onChanged: (_) => setState(() {}),
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _bodyText(String text) => Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.8),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 160,
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        color: AppTheme.csuMaroon.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VISION',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                          SizedBox(height: 4),
                          Text(
                            'CSU as a University with global stature.',
                            style: TextStyle(fontSize: 10),
                          ),
                          SizedBox(height: 12),
                          Text('MISSION',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                          SizedBox(height: 4),
                          Text(
                            'Cagayan State University shall produce globally competent graduates.',
                            style: TextStyle(fontSize: 10),
                          ),
                          SizedBox(height: 12),
                          Text('CORE VALUES',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                          SizedBox(height: 4),
                          Text(
                            'Competence\nCritical Thinker\nCreative Problem Solver\nCompetitive Performer\nNationally, Regionally and Globally',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
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
                              fontSize: 13,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: AppTheme.spaceSm),
                          const UniversityLetterhead(showDivider: false),
                          const SizedBox(height: AppTheme.spaceLg),
                          const Center(
                            child: Text(
                              'CERTIFICATE OF APPEARANCE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceXl),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              _bodyText('This is to certify that '),
                              _underlineField(_nameController, 'Name', width: 240),
                              _bodyText(' of '),
                              _underlineField(_officeController, 'Office', width: 260),
                              _bodyText(', has appeared at '),
                              _underlineField(_campusController, 'Campus', width: 260),
                              _bodyText(' on '),
                              _underlineField(_dateController, 'Date', width: 150),
                              _bodyText('.'),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceLg),
                          _bodyText('Purpose of appearance:'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _purposeController,
                            decoration: _underlineDecoration('Purpose'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                            minLines: 2,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: AppTheme.spaceLg),
                          _bodyText(
                            'This certificate is issued upon request for whatever legal or official purpose it may serve.',
                          ),
                          const SizedBox(height: AppTheme.spaceLg),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              _bodyText('Issued this '),
                              _underlineField(_dayController, 'Day', width: 60),
                              _bodyText(' day of '),
                              _underlineField(_monthYearController, 'Month Year', width: 120),
                              _bodyText(', at '),
                              _underlineField(_issuedAtController, 'Place', width: 260),
                              _bodyText('.'),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceXxl),
                          if (_users != null && _users!.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppTheme.spaceMd),
                              child: DropdownButtonFormField<String>(
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
                            ),
                            if (_selectedUserId != null &&
                                _designationsFor(_selectedUserId).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppTheme.spaceMd),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Designations',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    ..._designationsFor(_selectedUserId)
                                        .map((d) {
                                      final checked =
                                          _selectedDesignations.contains(d);
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
                                ),
                              ),
                          ],
                          Center(
                            child: Column(
                              children: [
                                const Text('_______________________________',
                                    style: TextStyle(fontSize: 14)),
                                Text(
                                  _selectedSignatoryName.isNotEmpty
                                      ? _selectedSignatoryName
                                      : _coordinatorController.text.trim(),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  _selectedSignatoryName.isNotEmpty
                                      ? (_selectedDesignations.isNotEmpty
                                          ? _selectedDesignations.join(', ')
                                          : _designationsFor(_selectedUserId)
                                              .join(', '))
                                      : _coordinatorTitle,
                                  style: const TextStyle(fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const Text('Cagayan State University',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceLg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _generating ? null : _generate,
                              icon: _generating
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.description),
                              label: Text(_generating
                                  ? 'Saving...'
                                  : 'Save Certificate'),
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
