import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/scholar_billing.dart';
import '../widgets/ui_components.dart';

class ScholarBillingScreen extends StatefulWidget {
  const ScholarBillingScreen({super.key});

  @override
  State<ScholarBillingScreen> createState() => ScholarBillingScreenState();
}

class ScholarBillingScreenState extends State<ScholarBillingScreen> {
  bool _loading = true;
  String? _error;
  bool _trainingMode = false;
  String _statusFilter = 'all';
  String _search = '';
  List<Map<String, dynamic>> _assessees = [];
  List<Map<String, dynamic>> _trainingBatches = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.get('/assessees'),
        ApiClient.get('/training-batches'),
      ]);
      if (!mounted) return;
      setState(() {
        _assessees = (results[0].data as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _trainingBatches = (results[1].data as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
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

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  String _money(double amount) {
    final peso = String.fromCharCode(8369);
    return '$peso${NumberFormat('#,##0.00', 'en_US').format(amount)}';
  }

  String _trainingDateLabel(Map<String, dynamic> batch) {
    String format(dynamic value) {
      final date = DateTime.tryParse(value?.toString() ?? '');
      return date == null ? '' : DateFormat('MMMM d, yyyy').format(date);
    }

    final start = format(batch['date_started']);
    final finish = format(batch['date_finished']);
    if (start.isEmpty && finish.isEmpty) return 'Dates not set';
    if (start.isEmpty) return finish;
    if (finish.isEmpty || finish == start) return start;
    return '$start - $finish';
  }

  List<_BillingGroup> get _billingGroups {
    final groups = <String, _BillingGroup>{};

    if (_trainingMode) {
      for (final batch in _trainingBatches) {
        final batchId = batch['id']?.toString();
        if (batchId == null) continue;
        final scholars = _assessees.where((assessee) =>
            assessee['training_batch_id']?.toString() == batchId &&
            assessee['training_candidate_type'] == 'scholar');
        if (scholars.isEmpty) continue;

        final center = batch['center'] is Map
            ? Map<String, dynamic>.from(batch['center'] as Map)
            : <String, dynamic>{};
        if (center['type'] != 'training') continue;
        final key = 'training:$batchId';
        groups[key] = _BillingGroup(
          key: key,
          type: 'training',
          centerName: center['name']?.toString() ?? 'Training center',
          qualification: batch['qualification']?.toString() ?? '',
          dateLabel: _trainingDateLabel(batch),
          assessor: batch['trainer_name']?.toString() ?? '',
          fee: _number(center['training_fee']),
          trainingBatchId: batch['id'] as int?,
          scholars: scholars.toList(),
        );
      }
    } else {
      for (final scholars in assessmentScholarGroups(_assessees)) {
        final assessee = scholars.first;
        final center = Map<String, dynamic>.from(assessee['center'] as Map);
        final qualification = assessee['qualification']?.toString() ?? '';
        final date = assessmentScholarDateLabel(scholars);
        final assessor = assessee['assessor']?.toString() ?? '';
        final key = 'assessment:${assessee['id']}';
        groups[key] = _BillingGroup(
          key: key,
          type: 'assessment',
          centerName: center['name']?.toString() ?? 'Assessment center',
          qualification: qualification,
          dateLabel: date,
          assessor: assessor,
          fee: _number(center['assessment_fee']),
          scholars: scholars,
        );
      }
    }

    return groups.values.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  List<_BillingGroup> get _groups {
    final search = _search.trim().toLowerCase();
    return _billingGroups.where((group) {
      if (_statusFilter == 'paid' && !group.isPaid) return false;
      if (_statusFilter == 'pending' && group.paidCount != 0) return false;
      if (_statusFilter == 'partial' &&
          (group.paidCount == 0 || group.isPaid)) {
        return false;
      }
      if (search.isEmpty) return true;
      final haystack = [
        group.centerName,
        group.qualification,
        group.dateLabel,
        group.assessor,
        ...group.scholars.map((scholar) => scholar['name']?.toString() ?? ''),
      ].join(' ').toLowerCase();
      return haystack.contains(search);
    }).toList();
  }

  Future<void> _receiveBankCheck(_BillingGroup group) async {
    final unpaid = group.scholars
        .where((scholar) => scholar['assessment_fee_paid'] != true)
        .toList();
    if (unpaid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive bank check?'),
        content: Text(
          'Mark the bank check as received for ${unpaid.length} scholar(s) '
          'in ${group.qualification}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm receipt'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.post(
        '/scholar-billings/receive-bank-check',
        data: {
          'billing_type': group.type,
          'ids': unpaid.map((scholar) => scholar['id']).toList(),
          if (group.trainingBatchId != null)
            'training_batch_id': group.trainingBatchId,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bank check received; scholar fees marked paid.')),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update scholar billing: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: load);

    final groups = _groups;
    final allGroups = _billingGroups;
    final totalAmount =
        groups.fold<double>(0, (total, group) => total + group.amount);
    final pendingAmount = groups
        .where((group) => !group.isPaid)
        .fold<double>(0, (total, group) => total + group.unpaidAmount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                icon: Icons.receipt_long_outlined,
                title: 'Scholar Billing Monitoring',
                subtitle: _trainingMode
                    ? 'Training scholar fees by center and training batch'
                    : 'External scholar assessment fees by consecutive dates and assessor',
                trailing: IconButton(
                  onPressed: load,
                  tooltip: 'Refresh billing',
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.fact_check_outlined),
                    label: Text('Assessment Centers'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.school_outlined),
                    label: Text('Training Centers'),
                  ),
                ],
                selected: {_trainingMode},
                onSelectionChanged: (selection) =>
                    setState(() => _trainingMode = selection.first),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Wrap(
                spacing: AppTheme.spaceMd,
                runSpacing: AppTheme.spaceSm,
                children: [
                  _summaryChip('Billings', '${groups.length}'),
                  _summaryChip('Expected bill', _money(totalAmount)),
                  _summaryChip('Outstanding', _money(pendingAmount)),
                  _summaryChip('Scholars',
                      '${groups.fold<int>(0, (sum, group) => sum + group.scholars.length)}'),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Wrap(
                spacing: AppTheme.spaceSm,
                runSpacing: AppTheme.spaceSm,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText:
                            'Search center, qualification, date, or scholar',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _search = value),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Payment status',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All statuses')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'partial', child: Text('Partially paid')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value ?? 'all'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: allGroups.isEmpty
                      ? 'No scholar billings yet'
                      : 'No billings match these filters',
                  subtitle: allGroups.isEmpty
                      ? _trainingMode
                          ? 'Training scholars must be assigned to a training batch to appear here.'
                          : 'Assessees marked External - Scholar will appear here.'
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg,
                    0,
                    AppTheme.spaceLg,
                    AppTheme.spaceLg,
                  ),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTheme.spaceSm),
                  itemBuilder: (context, index) => _billingCard(groups[index]),
                ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value) => Chip(
        label: Text('$label: $value'),
        visualDensity: VisualDensity.compact,
      );

  Widget _billingCard(_BillingGroup group) {
    final status = group.isPaid
        ? StatusBadge.success('Paid')
        : group.paidCount > 0
            ? StatusBadge.info('Partially paid')
            : StatusBadge.warning('Pending');
    final unpaidCount = group.scholars.length - group.paidCount;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.qualification.isEmpty
                    ? 'Unspecified qualification'
                    : group.qualification,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            status,
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${group.centerName} - ${group.dateLabel}\n'
            '${group.type == 'assessment' ? 'Assessor' : 'Trainer'}: '
            '${group.assessor.isEmpty ? 'Not assigned' : group.assessor}\n'
            '${group.scholars.length} scholar(s) - Actual bill: '
            '${_money(group.amount)}',
          ),
        ),
        children: [
          const Divider(),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _detail('Scholars', '${group.scholars.length}'),
              _detail('Fee per scholar', _money(group.fee)),
              _detail('Actual bill', _money(group.amount)),
              _detail('Paid', '${group.paidCount}'),
              _detail('Outstanding', _money(group.unpaidAmount)),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final scholar in group.scholars)
                  Chip(
                    avatar: Icon(
                      scholar['assessment_fee_paid'] == true
                          ? Icons.check_circle
                          : Icons.hourglass_empty,
                      size: 16,
                    ),
                    label: Text(scholar['name']?.toString() ?? 'Scholar'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          if (unpaidCount > 0) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _receiveBankCheck(group),
                icon: const Icon(Icons.account_balance, size: 18),
                label: Text('Receive bank check ($unpaidCount)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _BillingGroup {
  _BillingGroup({
    required this.key,
    required this.type,
    required this.centerName,
    required this.qualification,
    required this.dateLabel,
    required this.assessor,
    required this.fee,
    this.trainingBatchId,
    List<Map<String, dynamic>>? scholars,
  }) : scholars = scholars ?? [];

  final String key;
  final String type;
  final String centerName;
  final String qualification;
  final String dateLabel;
  final String assessor;
  final double fee;
  final int? trainingBatchId;
  final List<Map<String, dynamic>> scholars;

  int get paidCount => scholars
      .where((scholar) => scholar['assessment_fee_paid'] == true)
      .length;
  bool get isPaid => scholars.isNotEmpty && paidCount == scholars.length;
  double get amount => fee * scholars.length;
  double get unpaidAmount => fee * (scholars.length - paidCount);
}
