import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';
import 'payment_slip_print_screen.dart';

class PaymentSlipScreen extends StatefulWidget {
  const PaymentSlipScreen({super.key});

  @override
  State<PaymentSlipScreen> createState() => _PaymentSlipScreenState();
}

class _PaymentSlipScreenState extends State<PaymentSlipScreen> {
  List<dynamic>? _users;
  String? _selectedUserId;
  List<String> _selectedDesignations = [];

  List<dynamic>? _centers;
  List<Map<String, dynamic>> _availableQualifications = [];
  final Map<String, bool> _selectedQualifications = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<dynamic>? _slips;
  bool _slipsLoading = true;

  final _studentId = TextEditingController();
  final _course = TextEditingController();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _middleInitial = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCenters();
    _loadSlips();
    _loadUsers();
  }

  @override
  void dispose() {
    _studentId.dispose();
    _course.dispose();
    _lastName.dispose();
    _firstName.dispose();
    _middleInitial.dispose();
    super.dispose();
  }

  Future<void> _loadCenters() async {
    try {
      final res = await ApiClient.get('/centers');
      _centers = res.data as List<dynamic>;
      _buildQualificationList();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final res = await ApiClient.get('/users');
      setState(() => _users = res.data as List<dynamic>?);
    } catch (_) {}
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

  String get _officerName {
    if (_selectedUserId == null) return '';
    final u = _users?.firstWhere(
      (e) => e['id']?.toString() == _selectedUserId,
      orElse: () => <String, dynamic>{},
    );
    if (u == null) return '';
    final name = u['name']?.toString() ?? '';
    final ext = u['extension_name']?.toString() ?? '';
    return ext.isNotEmpty ? '$name $ext' : name;
  }

  String get _officerDesignations {
    return _selectedDesignations.join(', ');
  }

  void _buildQualificationList() {
    _availableQualifications = [];
    for (final c in _centers ?? []) {
      final name = c['name']?.toString() ?? '';
      final type = c['type']?.toString() ?? '';
      final fee = type == 'assessment'
          ? (c['assessment_fee'] as num?)?.toDouble() ?? 0
          : (c['training_fee'] as num?)?.toDouble() ?? 0;
      final quals = (c['qualifications'] as List<dynamic>? ?? []);
      for (final q in quals) {
        final label = q.toString();
        final key = '$name|$label|$type|$fee';
        _availableQualifications.add({
          'key': key,
          'center': name,
          'qualification': label,
          'type': type,
          'fee': fee,
        });
        _selectedQualifications[key] = false;
      }
    }
  }

  Future<void> _loadSlips() async {
    setState(() => _slipsLoading = true);
    try {
      final res = await ApiClient.get('/payment-slips');
      if (!mounted) return;
      setState(() {
        _slips = res.data as List<dynamic>;
        _slipsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _slipsLoading = false);
    }
  }

  double get _total {
    double total = 0;
    for (final q in _availableQualifications) {
      if (_selectedQualifications[q['key']] == true) {
        total += (q['fee'] as num).toDouble();
      }
    }
    return total;
  }

  List<Map<String, dynamic>> get _selectedItems {
    return _availableQualifications
        .where((q) => _selectedQualifications[q['key']] == true)
        .map((q) => {
              'qualification':
                  '${q['qualification']} (${q['type'] == 'assessment' ? 'Assessment' : 'Training'})',
              'amount': q['fee'],
            })
        .toList();
  }

  Future<void> _save() async {
    final items = _selectedItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one qualification')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ApiClient.post('/payment-slips', data: {
        'student_id': _studentId.text.trim(),
        'last_name': _lastName.text.trim(),
        'first_name': _firstName.text.trim(),
        'middle_name': _middleInitial.text.trim(),
        'course': _course.text.trim(),
        'section': '',
        'officer_name': _officerName,
        'officer_designations': _officerDesignations,
        'items': items,
        'total_amount': _total,
      });
      final slip = res.data as Map<String, dynamic>;
      _resetForm();
      _loadSlips();
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentSlipPrintScreen(
              slip: slip,
              processingOfficer: _officerName,
              processingOfficerDesignations: _officerDesignations,
              allQualifications: _availableQualifications,
              selectedKeys: _selectedQualifications,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  void _resetForm() {
    _studentId.clear();
    _course.clear();
    _lastName.clear();
    _firstName.clear();
    _middleInitial.clear();
    for (final key in _selectedQualifications.keys) {
      _selectedQualifications[key] = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _loadCenters);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.receipt_long,
                imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                title: 'Payment Slip',
                subtitle: 'Create a payment slip for assessment or training fees',
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // Student info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Student Information',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppTheme.spaceMd),
                      TextField(
                        controller: _studentId,
                        decoration: const InputDecoration(
                          labelText: 'ID Number',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _course,
                        decoration: const InputDecoration(
                          labelText: 'Course',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _middleInitial,
                        decoration: const InputDecoration(
                          labelText: 'M.I',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // Processing officer selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedUserId,
                        decoration: const InputDecoration(
                          labelText: 'Officer Name',
                          prefixIcon: Icon(Icons.person, size: 20),
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
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // Qualification selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Select Qualifications',
                              style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Text('Total: \u20B1${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.csuMaroon,
                              )),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      if (_availableQualifications.isEmpty)
                        const Text('No qualifications available from centers.')
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 350),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableQualifications.length,
                            itemBuilder: (context, index) {
                              final q = _availableQualifications[index];
                              final key = q['key'] as String;
                              return CheckboxListTile(
                                value: _selectedQualifications[key] ?? false,
                                onChanged: (v) {
                                  setState(() {
                                    _selectedQualifications[key] = v ?? false;
                                  });
                                },
                                title: Text(q['qualification'] as String),
                                subtitle: Text(
                                  '${q['center']} - ${q['type'] == 'assessment' ? 'Assessment' : 'Training'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                secondary: Text(
                                  '\u20B1${(q['fee'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                dense: true,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
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
                  label: Text(_saving ? 'Saving...' : 'Save & Preview'),
                ),
              ),

              const SizedBox(height: AppTheme.spaceXl),

              // Existing payment slips
              Text('Payment Slip Records',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppTheme.spaceMd),
              if (_slipsLoading)
                const LoadingState()
              else if (_slips == null || _slips!.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_outlined,
                  title: 'No payment slips yet',
                  subtitle: 'Created payment slips will appear here',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _slips!.length,
                  itemBuilder: (context, index) {
                    final slip = _slips![index] as Map<String, dynamic>;
                    final printed = slip['printed_count'] ?? 0;
                    final released = slip['released_count'] ?? 0;
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.spaceSm),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spaceMd),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.csuMaroon
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm),
                                ),
                                child: const Icon(Icons.receipt_long,
                                    color: AppTheme.csuMaroon, size: 22),
                              ),
                              const SizedBox(width: AppTheme.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Slip #${slip['id']} - ${slip['created_at']?.toString().split(' ').first ?? ''}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: AppTheme.spaceSm,
                                      children: [
                                        StatusBadge.info(
                                            'Printed: $printed'),
                                        StatusBadge.info(
                                            'Released: $released'),
                                        StatusBadge.success(
                                            '\u20B1${(slip['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) {
                                  switch (action) {
                                    case 'print':
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PaymentSlipPrintScreen(
                                            slip: slip,
                                            processingOfficer:
                                                slip['officer_name']?.toString() ?? _officerName,
                                            processingOfficerDesignations:
                                                slip['officer_designations']?.toString() ?? _officerDesignations,
                                          ),
                                        ),
                                      );
                                      break;
                                    case 'release':
                                      _incrementReleased(slip);
                                      break;
                                    case 'delete':
                                      _deleteSlip(slip);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'print',
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.print, size: 20),
                                      title: Text('Print / View'),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'release',
                                    child: ListTile(
                                      leading: Icon(Icons.check_circle,
                                          size: 20),
                                      title: Text('Mark Released'),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete,
                                          size: 20, color: AppTheme.error),
                                      title: Text('Delete',
                                          style: TextStyle(
                                              color: AppTheme.error)),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _incrementReleased(Map<String, dynamic> slip) async {
    try {
      await ApiClient.post('/payment-slips/${slip['id']}/released');
      _loadSlips();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as released')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteSlip(Map<String, dynamic> slip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Slip'),
        content: Text('Delete payment slip #${slip['id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/payment-slips/${slip['id']}');
      _loadSlips();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment slip deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}
