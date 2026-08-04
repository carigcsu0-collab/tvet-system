import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';
import 'package:intl/intl.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  List<dynamic>? _logs;
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
      final res = await ApiClient.get('/activity-logs');
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _logs = data['data'] as List<dynamic>?;
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
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_logs == null || _logs!.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No activity logs yet',
        subtitle: 'User actions will be recorded here',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        itemCount: _logs!.length,
        itemBuilder: (context, index) {
          final log = _logs![index] as Map<String, dynamic>;
          final user = log['user'] as Map<String, dynamic>?;
          final date = log['created_at']?.toString() ?? '';
          final dt = DateTime.tryParse(date);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.csuMaroon.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: AppTheme.csuMaroon,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log['action']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log['description']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: AppTheme.spaceSm,
                            runSpacing: 2,
                            children: [
                              StatusBadge.info(
                                'By: ${user?['name'] ?? 'Unknown'}',
                              ),
                              if (dt != null)
                                Text(
                                  DateFormat('MMM dd, yyyy hh:mm a').format(dt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
