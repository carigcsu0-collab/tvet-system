import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _centers = [];
  List<dynamic> _assessees = [];
  List<dynamic> _documents = [];

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
        ApiClient.get('/centers'),
        ApiClient.get('/assessees'),
        ApiClient.get('/documents'),
      ]);
      if (!mounted) return;
      setState(() {
        _centers = results[0].data as List<dynamic>? ?? [];
        _assessees = results[1].data as List<dynamic>? ?? [];
        _documents = results[2].data as List<dynamic>? ?? [];
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }
    if (_error != null) {
      return ErrorState(message: 'Failed to load: $_error', onRetry: _load);
    }

    final now = DateTime.now();
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200
        ? 4
        : screenWidth > 600
            ? 2
            : 1;

    // Center stats
    final pendingCenters =
        _centers.where((c) => c['status'] == 'Pending').length;
    final completeCenters =
        _centers.where((c) => c['status'] != 'Pending').length;

    // Document status counts
    int docSaved = 0, docReceived = 0, docSpecialOrder = 0, docVoucher = 0;
    for (final d in _documents) {
      final status = d['status']?.toString() ?? 'saved';
      switch (status) {
        case 'saved':
          docSaved++;
          break;
        case 'received':
          docReceived++;
          break;
        case 'special_order':
          docSpecialOrder++;
          break;
        case 'voucher_received':
          docVoucher++;
          break;
      }
    }

    // Upcoming assessments (assessment_date in the future)
    final upcoming = <Map<String, dynamic>>[];
    for (final a in _assessees) {
      final dateStr = a['assessment_date']?.toString() ?? '';
      if (dateStr.isEmpty) continue;
      final date = DateTime.tryParse(dateStr);
      if (date != null && !date.isBefore(now)) {
        upcoming.add({
          'name': a['name']?.toString() ?? '',
          'qualification': a['qualification']?.toString() ?? '',
          'date': date,
          'assessor': a['assessor']?.toString() ?? '',
        });
      }
    }
    upcoming.sort((a, b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Assessment vs training counts
    final assessmentCount =
        _assessees.where((a) => a['competency'] != null).length;
    final pendingCompetency = _assessees.where((a) {
      final c = a['competency']?.toString() ?? '';
      return c.isEmpty || c == 'Pending' || c == 'not_yet_competent';
    }).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary stat cards
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppTheme.spaceMd,
                  mainAxisSpacing: AppTheme.spaceMd,
                  childAspectRatio: crossAxisCount == 1 ? 3.5 : 2.2,
                  children: [
                    _StatCard(
                      title: 'Total Centers',
                      value: _centers.length.toString(),
                      icon: Icons.business,
                      color: AppTheme.info,
                    ),
                    _StatCard(
                      title: 'Total Assessees',
                      value: _assessees.length.toString(),
                      icon: Icons.people,
                      color: AppTheme.success,
                    ),
                    _StatCard(
                      title: 'Total Documents',
                      value: _documents.length.toString(),
                      icon: Icons.description,
                      color: AppTheme.csuMaroon,
                    ),
                    _StatCard(
                      title: 'Pending Centers',
                      value: pendingCenters.toString(),
                      icon: Icons.pending_actions,
                      color: AppTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXxl),

                // Document status section
                const SectionHeader(
                  icon: Icons.fact_check,
                  imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                  title: 'Document Status',
                  subtitle: 'Overview of document workflow stages',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Wrap(
                  spacing: AppTheme.spaceSm,
                  runSpacing: AppTheme.spaceSm,
                  children: [
                    _StatusChip(label: 'Saved', count: docSaved, color: AppTheme.info),
                    _StatusChip(label: 'Received', count: docReceived, color: AppTheme.warning),
                    _StatusChip(label: 'Special Order', count: docSpecialOrder, color: Colors.purple),
                    _StatusChip(label: 'Voucher Received', count: docVoucher, color: AppTheme.success),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXxl),

                // Center status section
                const SectionHeader(
                  icon: Icons.business,
                  imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                  title: 'Center Status',
                  subtitle: 'Assessment and training center overview',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Wrap(
                  spacing: AppTheme.spaceSm,
                  runSpacing: AppTheme.spaceSm,
                  children: [
                    _StatusChip(label: 'Complete', count: completeCenters, color: AppTheme.success),
                    _StatusChip(label: 'Pending', count: pendingCenters, color: AppTheme.warning),
                    _StatusChip(label: 'Pending Competency', count: pendingCompetency, color: AppTheme.error),
                    _StatusChip(label: 'Assessed', count: assessmentCount, color: AppTheme.success),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXxl),

                // Upcoming assessments
                const SectionHeader(
                  icon: Icons.event,
                  imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                  title: 'Upcoming Assessments / Training',
                  subtitle: 'Scheduled assessments in the coming days',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                if (upcoming.isEmpty)
                  const EmptyState(
                    icon: Icons.event_busy,
                    title: 'No upcoming assessments',
                    subtitle: 'Scheduled assessments will appear here',
                  )
                else
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateColor.resolveWith(
                            (_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Qualification')),
                          DataColumn(label: Text('Assessor')),
                        ],
                        rows: upcoming.take(20).map<DataRow>((u) {
                          final date = u['date'] as DateTime;
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                  DateFormat('MMMM dd, yyyy').format(date))),
                              DataCell(Text(u['name'].toString())),
                              DataCell(Text(u['qualification'].toString())),
                              DataCell(Text(u['assessor'].toString())),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: AppTheme.spaceXxl),

                // Center qualifications with expiration
                const SectionHeader(
                  icon: Icons.verified,
                  imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                  title: 'Center Qualifications & Expiration',
                  subtitle: 'Track qualification validity and renewal dates',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateColor.resolveWith(
                          (_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                      columns: const [
                        DataColumn(label: Text('Center')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Qualifications')),
                        DataColumn(label: Text('Expiration Date')),
                        DataColumn(label: Text('Audit Date')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _centers.map<DataRow>((c) {
                        final name = c['name']?.toString() ?? '';
                        final type = c['type']?.toString() ?? '';
                        final quals = (c['qualifications'] as List<dynamic>? ?? [])
                            .join(', ');
                        final expDate = c['expiration_date']?.toString() ?? '';
                        final auditDate = c['audit_date']?.toString() ?? '';
                        final auditCompletedAt = c['audit_completed_at']?.toString();
                        final auditCompletedDate = auditCompletedAt != null && auditCompletedAt.isNotEmpty
                            ? DateTime.tryParse(auditCompletedAt)
                            : null;
                        final status = c['status']?.toString() ?? 'Complete';
                        return DataRow(
                          cells: [
                            DataCell(Text(name)),
                            DataCell(Text(type == 'assessment'
                                ? 'Assessment'
                                : 'Training')),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 300),
                                child: Text(
                                  quals.isEmpty ? 'None' : quals,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(expDate.isEmpty
                                ? 'None'
                                : DateFormat('MMMM dd, yyyy').format(
                                    DateTime.tryParse(expDate) ?? DateTime.now()))),
                            DataCell(auditCompletedDate != null
                                ? StatusBadge.success(
                                    'Audited ${DateFormat('MMMM dd, yyyy hh:mm a').format(auditCompletedDate)}',
                                  )
                                : Text(auditDate.isEmpty
                                    ? 'None'
                                    : DateFormat('MMMM dd, yyyy').format(
                                        DateTime.tryParse(auditDate) ?? DateTime.now()))),
                            DataCell(
                              status == 'Pending'
                                  ? StatusBadge.warning(status)
                                  : StatusBadge.success(status),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spaceXl),

                // Price list
                const SectionHeader(
                  icon: Icons.payments,
                  imageUrl: 'https://csu.edu.ph/img/csulogo_index.png',
                  title: 'Qualification Price List',
                  subtitle: 'Assessment and training fees per qualification',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateColor.resolveWith(
                          (_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                      columns: const [
                        DataColumn(label: Text('Center')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Qualification')),
                        DataColumn(label: Text('Fee')),
                      ],
                      rows: _centers.expand<DataRow>((c) {
                        final name = c['name']?.toString() ?? '';
                        final type = c['type']?.toString() ?? '';
                        final fee = type == 'assessment'
                            ? (c['assessment_fee'] as num?)?.toDouble() ?? 0
                            : (c['training_fee'] as num?)?.toDouble() ?? 0;
                        final quals =
                            (c['qualifications'] as List<dynamic>? ?? []);
                        if (quals.isEmpty) {
                          return [
                            DataRow(cells: [
                              DataCell(Text(name)),
                              DataCell(Text(type == 'assessment'
                                  ? 'Assessment'
                                  : 'Training')),
                              const DataCell(Text('None')),
                              DataCell(Text('\u20B1${fee.toStringAsFixed(2)}')),
                            ]),
                          ];
                        }
                        return quals.map<DataRow>((q) {
                          return DataRow(cells: [
                            DataCell(Text(name)),
                            DataCell(Text(type == 'assessment'
                                ? 'Assessment'
                                : 'Training')),
                            DataCell(Text(q.toString())),
                            DataCell(Text('\u20B1${fee.toStringAsFixed(2)}')),
                          ]);
                        }).toList();
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.08),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}


class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
