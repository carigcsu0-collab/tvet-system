import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
import '../../../core/records_refresh.dart';
import '../widgets/ui_components.dart';
import 'edit_document_screen.dart';
import 'print_preview_screen.dart';
import 'rap_print_screen.dart';
import 'pei_print_screen.dart';

class DocumentRecordsScreen extends StatefulWidget {
  const DocumentRecordsScreen({super.key});

  @override
  State<DocumentRecordsScreen> createState() => DocumentRecordsScreenState();
}

class DocumentRecordsScreenState extends State<DocumentRecordsScreen> {
  List<dynamic>? _records;
  bool _loading = true;
  String? _error;
  String _typeFilter = 'all';
  RecordsRefresh? _recordsRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordsRefresh = context.read<RecordsRefresh>();
      _recordsRefresh?.addListener(_load);
    });
  }

  @override
  void dispose() {
    _recordsRefresh?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get('/documents');
      if (!mounted) return;
      setState(() {
        _records = res.data as List<dynamic>;
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

  Future<void> load() => _load();

  Future<void> _delete(dynamic record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Delete ${record['code'] ?? 'this document'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.delete('/documents/${record['code']}');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _markReceived(dynamic record) async {
    final initial = record['received_at'] != null
        ? DateTime.tryParse(record['received_at'].toString())
        : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    final officeController = TextEditingController(
      text: record['received_by_office']?.toString() ?? '',
    );
    final office = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Received By Office'),
        content: TextField(
          controller: officeController,
          decoration: const InputDecoration(
            labelText: 'Office',
            hintText: 'Enter the receiving office',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(officeController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final now = DateTime.now();
    final receivedAt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      now.hour,
      now.minute,
      now.second,
    );
    final formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(receivedAt);

    final data = <String, dynamic>{'received_at': formatted};
    if (office != null && office.isNotEmpty) {
      data['received_by_office'] = office;
    }

    try {
      await ApiClient.post(
        '/documents/${record['code']}/receive',
        data: data,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as received')),
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

  List<dynamic> get _filteredRecords {
    if (_records == null) return [];
    if (_typeFilter == 'all') return _records!;
    return _records!.where((r) {
      final slug = r['document_type']?['slug']?.toString() ?? '';
      return slug == _typeFilter;
    }).toList();
  }

  List<String> get _availableTypes {
    if (_records == null) return [];
    final slugs = <String>{};
    final names = <String, String>{};
    for (final r in _records!) {
      final slug = r['document_type']?['slug']?.toString() ?? '';
      final name = r['document_type']?['name']?.toString() ?? '';
      if (slug.isNotEmpty) {
        slugs.add(slug);
        names[slug] = name;
      }
    }
    return slugs.toList()..sort((a, b) => names[a]!.compareTo(names[b]!));
  }

  String _typeName(String slug) {
    if (_records == null) return slug;
    for (final r in _records!) {
      final s = r['document_type']?['slug']?.toString() ?? '';
      if (s == slug) return r['document_type']?['name']?.toString() ?? slug;
    }
    return slug;
  }

  int _codeNumber(String code) {
    final parts = code.split('-');
    return int.tryParse(parts.last) ?? 0;
  }

  Set<String> get _lastDeletableCodes {
    if (_records == null) return {};
    final maxByType = <String, int>{};
    for (final r in _records!) {
      final received = r['received_at'] != null;
      if (received) continue;
      final typeId = r['document_type_id']?.toString() ?? '';
      final year = r['year']?.toString() ?? '';
      final key = '$typeId-$year';
      final num = _codeNumber(r['code']?.toString() ?? '');
      if (num > (maxByType[key] ?? 0)) {
        maxByType[key] = num;
      }
    }
    final result = <String>{};
    for (final r in _records!) {
      final received = r['received_at'] != null;
      if (received) continue;
      final typeId = r['document_type_id']?.toString() ?? '';
      final year = r['year']?.toString() ?? '';
      final key = '$typeId-$year';
      final code = r['code']?.toString() ?? '';
      if (_codeNumber(code) == maxByType[key]) {
        result.add(code);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    if (_records == null || _records!.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open,
        title: 'No documents saved yet',
        subtitle: 'Created documents will appear here',
      );
    }

    final filtered = _filteredRecords;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deletableCodes = _lastDeletableCodes;

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: DropdownButtonFormField<String>(
                    initialValue: _typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter by document type',
                      isDense: true,
                      prefixIcon: Icon(Icons.filter_list, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Documents'),
                      ),
                      ..._availableTypes.map((slug) => DropdownMenuItem(
                        value: slug,
                        child: Text(_typeName(slug)),
                      )),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _typeFilter = v);
                    },
                  ),
                ),
              ),
              if (_typeFilter != 'all') ...[
                const SizedBox(width: AppTheme.spaceSm),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Clear filter',
                  onPressed: () => setState(() => _typeFilter = 'all'),
                ),
              ],
            ],
          ),
        ),
        // Records list
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No matching documents',
                  subtitle: 'Try a different filter',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final record = filtered[index] as Map<String, dynamic>;
                      final type = record['document_type']?['name'] ?? 'Document';
                      final received = record['received_at'] as String?;
                      final receivedDate = received != null
                          ? DateTime.tryParse(received)
                          : null;
                      final receivedByOffice =
                          record['received_by_office']?.toString() ?? '';
                      final user = record['user'] as Map<String, dynamic>?;
                      final receivedByName = user?['name']?.toString() ?? '';
                      final code = record['code']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceLg),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.csuMaroon.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  ),
                                  child: const Icon(
                                    Icons.description,
                                    color: AppTheme.csuMaroon,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (receivedDate != null) ...[
                                        StatusBadge.success(
                                          'Received: ${DateFormat('MMMM dd, yyyy hh:mm a').format(receivedDate)}',
                                        ),
                                        if (receivedByName.isNotEmpty ||
                                            receivedByOffice.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: AppTheme.spaceSm,
                                            runSpacing: 2,
                                            children: [
                                              if (receivedByName.isNotEmpty)
                                                StatusBadge.info(
                                                  'By: $receivedByName',
                                                ),
                                              if (receivedByOffice.isNotEmpty)
                                                StatusBadge.info(
                                                  'Office: $receivedByOffice',
                                                ),
                                            ],
                                          ),
                                        ],
                                      ] else
                                        StatusBadge.warning('Not received'),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'receive':
                                        _markReceived(record);
                                        break;
                                      case 'print':
                                        final slug = (record['document_type']
                                                as Map<String, dynamic>?)?['slug']
                                            ?.toString() ??
                                            '';
                                        if (slug == AppConstants.rapSlug) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  RapPrintScreen(code: code),
                                            ),
                                          );
                                        } else if (slug == AppConstants.peiSlug) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PeiPrintScreen(code: code),
                                            ),
                                          );
                                        } else {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PrintPreviewScreen(code: code),
                                            ),
                                          );
                                        }
                                        break;
                                      case 'edit':
                                        Navigator.of(context)
                                            .push(
                                          MaterialPageRoute(
                                            builder: (_) => EditDocumentScreen(code: code),
                                          ),
                                        )
                                            .then((result) {
                                          if (result == true) _load();
                                        });
                                        break;
                                      case 'delete':
                                        _delete(record);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (receivedDate == null)
                                      const PopupMenuItem(
                                        value: 'receive',
                                        child: ListTile(
                                          leading: Icon(Icons.mark_email_read_outlined, size: 20),
                                          title: Text('Mark received'),
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'print',
                                      child: ListTile(
                                        leading: Icon(Icons.print, size: 20),
                                        title: Text('Print / View'),
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit, size: 20),
                                        title: Text('Edit'),
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                    if (receivedDate == null && deletableCodes.contains(code))
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete, size: 20, color: AppTheme.error),
                                          title: Text('Delete',
                                              style: TextStyle(color: AppTheme.error)),
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
                ),
        ),
      ],
    );
  }
}
