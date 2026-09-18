import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';
import 'training_attendance_screen.dart';
import 'training_billing_screen.dart';

/// Lists training batches (a training center + qualification + date range)
/// and links to each batch's Attendance Monitoring and Billing Statement.
class TrainingBatchesScreen extends StatefulWidget {
  const TrainingBatchesScreen({super.key});

  @override
  State<TrainingBatchesScreen> createState() => TrainingBatchesScreenState();
}

class TrainingBatchesScreenState extends State<TrainingBatchesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _batches = [];
  List<dynamic> _trainingCenters = [];

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
        ApiClient.get('/training-batches'),
        ApiClient.get('/centers'),
      ]);
      if (!mounted) return;
      setState(() {
        _batches = results[0].data as List<dynamic>;
        _trainingCenters = (results[1].data as List<dynamic>)
            .where((c) => c['type'] == 'training')
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

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.isEmpty) return '';
    final plainDateMatch = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(text);
    if (plainDateMatch != null) return text;
    final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (isoMatch != null) return isoMatch.group(1)!;
    final date = DateTime.tryParse(text);
    if (date != null) return DateFormat('yyyy-MM-dd').format(date);
    return text;
  }

  Future<void> _showForm({Map<String, dynamic>? batch}) async {
    final formKey = GlobalKey<FormState>();
    int? centerId = batch?['center_id'] as int? ?? (_trainingCenters.isNotEmpty ? _trainingCenters.first['id'] as int : null);
    final qualification = TextEditingController(text: batch?['qualification'] ?? '');
    final trainerName = TextEditingController(text: batch?['trainer_name'] ?? '');
    final nttcNo = TextEditingController(text: batch?['nttc_no'] ?? '');
    final location = TextEditingController(text: batch?['location'] ?? '');
    final durationHours = TextEditingController(text: batch?['duration_hours'] ?? '');
    final dateStarted = TextEditingController(text: _formatDate(batch?['date_started']));
    final dateFinished = TextEditingController(text: _formatDate(batch?['date_finished']));

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(batch == null ? 'Add Training Batch' : 'Edit Training Batch'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: centerId,
                    decoration: const InputDecoration(labelText: 'Training Center'),
                    items: _trainingCenters
                        .map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']?.toString() ?? '')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => centerId = v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: qualification,
                    decoration: const InputDecoration(labelText: 'Qualification / Program'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: trainerName, decoration: const InputDecoration(labelText: 'Trainer Name')),
                  const SizedBox(height: 8),
                  TextFormField(controller: nttcNo, decoration: const InputDecoration(labelText: 'NTTC No.')),
                  const SizedBox(height: 8),
                  TextFormField(controller: location, decoration: const InputDecoration(labelText: 'Location of Training')),
                  const SizedBox(height: 8),
                  TextFormField(controller: durationHours, decoration: const InputDecoration(labelText: 'Duration (No. of Training Hours)')),
                  const SizedBox(height: 8),
                  TextFormField(controller: dateStarted, decoration: const InputDecoration(labelText: 'Date Started (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  TextFormField(controller: dateFinished, decoration: const InputDecoration(labelText: 'Date Finished (YYYY-MM-DD)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate() || centerId == null) return;
                final payload = <String, dynamic>{
                  'center_id': centerId,
                  'qualification': qualification.text.trim(),
                  'trainer_name': trainerName.text.trim(),
                  'nttc_no': nttcNo.text.trim(),
                  'location': location.text.trim(),
                  'duration_hours': durationHours.text.trim(),
                  'date_started': dateStarted.text.trim().isEmpty ? null : dateStarted.text.trim(),
                  'date_finished': dateFinished.text.trim().isEmpty ? null : dateFinished.text.trim(),
                };
                Navigator.pop(context);
                _save(batch?['id'], payload);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(int? id, Map<String, dynamic> payload) async {
    try {
      if (id == null) {
        await ApiClient.post('/training-batches', data: payload);
      } else {
        await ApiClient.put('/training-batches/$id', data: payload);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text('Delete "${batch['qualification']}"? This also removes its attendance records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/training-batches/${batch['id']}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: load);

    if (_trainingCenters.isEmpty) {
      return EmptyState(
        icon: Icons.school_outlined,
        title: 'No training centers yet',
        subtitle: 'Add a training center first under Centers > Training Centers',
        action: FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh, size: 18), label: const Text('Reload')),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: load),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Training Batch'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _batches.isEmpty
              ? const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No training batches yet',
                  subtitle: 'Add a batch to start tracking attendance and billing',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                  itemCount: _batches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
                  itemBuilder: (context, index) {
                    final b = _batches[index] as Map<String, dynamic>;
                    final center = b['center'] as Map<String, dynamic>?;
                    final traineeCount = b['trainees_count'] ?? 0;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b['qualification']?.toString() ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text(center?['name']?.toString() ?? '',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                StatusBadge.info('$traineeCount trainee${traineeCount == 1 ? '' : 's'}'),
                                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(batch: b)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error), onPressed: () => _delete(b)),
                              ],
                            ),
                            if ((b['date_started'] != null) || (b['date_finished'] != null))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${_formatDate(b['date_started'])} - ${_formatDate(b['date_finished'])}'
                                  '${(b['trainer_name'] ?? '').toString().isNotEmpty ? ' • Trainer: ${b['trainer_name']}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            const SizedBox(height: AppTheme.spaceSm),
                            Wrap(
                              spacing: AppTheme.spaceSm,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => TrainingAttendanceScreen(batch: b),
                                  )),
                                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                                  label: const Text('Attendance'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => TrainingBillingScreen(batch: b),
                                  )),
                                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                  label: const Text('Billing Statement'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
