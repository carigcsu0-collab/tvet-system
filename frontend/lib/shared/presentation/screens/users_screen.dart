import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic>? _users;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _friendlyError(Object e) {
    try {
      if (e is DioException) {
        final res = e.response;
        final data = res?.data;
        if (data is Map<String, dynamic>) {
          final msg = (data['message']?.toString() ?? '').trim();
          final errors = data['errors'];
          if (errors is Map<String, dynamic> && errors.isNotEmpty) {
            final parts = <String>[];
            errors.forEach((k, v) {
              if (v is List && v.isNotEmpty) parts.add(v.first.toString());
            });
            if (parts.isNotEmpty) return parts.join('\n');
          }
          if (msg.isNotEmpty) return msg;
        } else if (data is String && data.trim().isNotEmpty) {
          return data.trim();
        }
        if (res?.statusCode == 422) {
          return 'Validation failed. Please check your input.';
        }
        if (res?.statusCode == 500) {
          return 'Server error. Please try again or contact support.';
        }
      }
    } catch (_) {}
    return e.toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get('/users');
      if (!mounted) return;
      setState(() {
        _users = res.data as List<dynamic>?;
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

  Future<bool> _createUser(Map<String, dynamic> data) async {
    try {
      await ApiClient.post('/users', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User account created')),
        );
      }
      _load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: ${_friendlyError(e)}')),
        );
      }
      return false;
    }
  }

  Future<bool> _updateUser(int id, Map<String, dynamic> data) async {
    try {
      await ApiClient.put('/users/$id', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User account updated')),
        );
      }
      _load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: ${_friendlyError(e)}')),
        );
      }
      return false;
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user'),
        content: Text('Delete ${user['name'] ?? 'this user'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/users/${user['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${_friendlyError(e)}')),
        );
      }
    }
  }

  Future<void> _showForm([Map<String, dynamic>? user]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: user?['name']?.toString() ?? '');
    final extName = TextEditingController(text: user?['extension_name']?.toString() ?? '');
    final email = TextEditingController(text: user?['email']?.toString() ?? '');
    final password = TextEditingController();
    final designations = List<TextEditingController>.from(
      (user?['designations'] as List<dynamic>? ?? [])
          .map((d) => TextEditingController(text: d.toString())),
    );
    var role = (user?['role']?.toString() ?? 'coordinator').toLowerCase();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Add User Account' : 'Edit User Account'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: extName,
                      decoration: const InputDecoration(
                        labelText: 'Extension Name',
                        hintText: 'e.g. Jr., Sr., PhD',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: user == null ? 'Password' : 'New Password',
                        helperText: user == null
                            ? null
                            : 'Leave blank to keep current password',
                      ),
                      validator: (v) {
                        if (user == null) {
                          return v == null || v.trim().isEmpty
                              ? 'Required'
                              : null;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'coordinator', child: Text('Coordinator')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => role = v ?? 'coordinator'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Designations',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          tooltip: 'Add designation',
                          onPressed: () => setDialogState(
                              () => designations.add(TextEditingController())),
                        ),
                      ],
                    ),
                    ...List.generate(designations.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: designations[i],
                                decoration: InputDecoration(
                                  labelText: 'Designation ${i + 1}',
                                  hintText: 'e.g. TVET Coordinator',
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20, color: AppTheme.error),
                              onPressed: designations.length == 1
                                  ? null
                                  : () => setDialogState(
                                      () => designations.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => submitting = true);
                      final data = <String, dynamic>{
                        'name': name.text.trim(),
                        'extension_name': extName.text.trim(),
                        'designations': designations
                            .map((d) => d.text.trim())
                            .where((d) => d.isNotEmpty)
                            .toList(),
                        'email': email.text.trim(),
                        'role': role,
                      };
                      if (password.text.trim().isNotEmpty) {
                        data['password'] = password.text;
                      }
                      final ok = user == null
                          ? await _createUser(data)
                          : await _updateUser(user['id'] as int, data);
                      setDialogState(() => submitting = false);
                      if (ok && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(user == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final list = _users ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.csuMaroon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.people, color: AppTheme.csuMaroon, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  '${list.length} user account${list.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add User'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No user accounts yet',
                  subtitle: 'Add users to manage access',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateColor.resolveWith(
                          (_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Designations')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: list.map<DataRow>((u) {
                        final name = u['name']?.toString() ?? 'Unknown';
                        final ext = u['extension_name']?.toString() ?? '';
                        final fullName = ext.isNotEmpty ? '$name $ext' : name;
                        final desigs = (u['designations'] as List<dynamic>? ?? [])
                            .join(', ');
                        final email = u['email']?.toString() ?? '';
                        final role = u['role']?.toString() ?? 'coordinator';
                        return DataRow(
                          cells: [
                            DataCell(Text(fullName)),
                            DataCell(Text(desigs.isEmpty ? 'None' : desigs)),
                            DataCell(Text(email)),
                            DataCell(StatusBadge.info(
                                role[0].toUpperCase() + role.substring(1))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit',
                                  onPressed: () => _showForm(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: AppTheme.error),
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteUser(u),
                                ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
