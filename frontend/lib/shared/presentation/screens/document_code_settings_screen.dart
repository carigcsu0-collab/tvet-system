import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/constants.dart';
import '../widgets/ui_components.dart';

class DocumentCodeSettingsScreen extends StatefulWidget {
  const DocumentCodeSettingsScreen({super.key});

  @override
  State<DocumentCodeSettingsScreen> createState() =>
      _DocumentCodeSettingsScreenState();
}

class _CodeSetting {
  final String slug;
  final String name;
  final TextEditingController prefix;
  final TextEditingController activeYear;
  final TextEditingController padding;
  final TextEditingController nextNumber;
  bool saving;

  _CodeSetting({
    required this.slug,
    required this.name,
    required String prefixValue,
    required int activeYearValue,
    required int paddingValue,
    required int nextNumberValue,
  })  : prefix = TextEditingController(text: prefixValue),
        activeYear = TextEditingController(
          text: activeYearValue == 0 ? '' : '$activeYearValue',
        ),
        padding = TextEditingController(text: '$paddingValue'),
        nextNumber = TextEditingController(text: '$nextNumberValue'),
        saving = false;

  int get effectiveYear {
    final typed = int.tryParse(activeYear.text.trim());
    return typed ?? DateTime.now().year;
  }

  String get previewCode {
    final n = int.tryParse(nextNumber.text.trim()) ?? 1;
    final pad = int.tryParse(padding.text.trim()) ?? 3;
    return '${prefix.text.trim()}-$effectiveYear-${n.toString().padLeft(pad.clamp(1, 10), '0')}';
  }

  void dispose() {
    prefix.dispose();
    activeYear.dispose();
    padding.dispose();
    nextNumber.dispose();
  }
}

class _DocumentCodeSettingsScreenState
    extends State<DocumentCodeSettingsScreen> {
  List<_CodeSetting> _settings = [];
  final _coordinatorController = TextEditingController();
  final _titleController = TextEditingController();
  final _campusController = TextEditingController();
  final _issuedAtController = TextEditingController();
  bool _defaultsSaving = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final s in _settings) {
      s.dispose();
    }
    _coordinatorController.dispose();
    _titleController.dispose();
    _campusController.dispose();
    _issuedAtController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get('/document-code-settings');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      final coordinatorRes =
          await ApiClient.get('/settings/DEFAULT_COORDINATOR_NAME');
      final titleRes = await ApiClient.get('/settings/DEFAULT_COORDINATOR_TITLE');
      final campusRes = await ApiClient.get('/settings/DEFAULT_CAMPUS_NAME');
      final issuedRes = await ApiClient.get('/settings/DEFAULT_ISSUED_AT');
      for (final s in _settings) {
        s.dispose();
      }
      if (!mounted) return;
      setState(() {
        _settings = list
            .map(
              (e) => _CodeSetting(
                slug: e['slug']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
                prefixValue: e['prefix']?.toString() ?? '',
                activeYearValue:
                    int.tryParse('${e['active_year'] ?? 0}') ?? 0,
                paddingValue: int.tryParse('${e['padding'] ?? 3}') ?? 3,
                nextNumberValue:
                    int.tryParse('${e['next_number'] ?? 1}') ?? 1,
              ),
            )
            .toList();

        final knownSlugs = <String, String>{
          AppConstants.endorsementSlug: 'Endorsement',
        };
        for (final entry in knownSlugs.entries) {
          if (_settings.any((s) => s.slug == entry.key)) continue;
          _settings.add(_CodeSetting(
            slug: entry.key,
            name: entry.value,
            prefixValue: '',
            activeYearValue: DateTime.now().year,
            paddingValue: 3,
            nextNumberValue: 1,
          ));
        }
        _coordinatorController.text =
            (coordinatorRes.data['value'] as String?) ?? '';
        _titleController.text = (titleRes.data['value'] as String?) ?? '';
        _campusController.text = (campusRes.data['value'] as String?) ?? '';
        _issuedAtController.text = (issuedRes.data['value'] as String?) ?? '';
      });
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save(_CodeSetting setting) async {
    final prefix = setting.prefix.text.trim();
    final padding = int.tryParse(setting.padding.text.trim());
    final number = int.tryParse(setting.nextNumber.text.trim());
    final activeYear = int.tryParse(setting.activeYear.text.trim());

    if (prefix.isEmpty) {
      _notify('Prefix is required for ${setting.name}', isError: true);
      return;
    }
    if (padding == null || padding < 1 || padding > 10) {
      _notify('Padding must be between 1 and 10', isError: true);
      return;
    }
    if (number == null || number < 1) {
      _notify('Next number must be 1 or greater', isError: true);
      return;
    }

    setState(() => setting.saving = true);
    try {
      await ApiClient.put(
        '/document-code-settings/${setting.slug}',
        data: {
          'prefix': prefix,
          'active_year': activeYear,
          'padding': padding,
          'next_number': number,
        },
      );
      _notify('Saved ${setting.name}');
    } catch (e) {
      _notify('Failed to save ${setting.name}: $e', isError: true);
    } finally {
      if (mounted) setState(() => setting.saving = false);
    }
  }

  Future<void> _saveDefaults() async {
    final coordinator = _coordinatorController.text.trim();
    final title = _titleController.text.trim();
    final campus = _campusController.text.trim();
    final issuedAt = _issuedAtController.text.trim();

    if (coordinator.isEmpty ||
        title.isEmpty ||
        campus.isEmpty ||
        issuedAt.isEmpty) {
      _notify('All default fields are required', isError: true);
      return;
    }

    setState(() => _defaultsSaving = true);
    try {
      await ApiClient.put(
        '/settings/DEFAULT_COORDINATOR_NAME',
        data: {'value': coordinator},
      );
      await ApiClient.put(
        '/settings/DEFAULT_COORDINATOR_TITLE',
        data: {'value': title},
      );
      await ApiClient.put(
        '/settings/DEFAULT_CAMPUS_NAME',
        data: {'value': campus},
      );
      await ApiClient.put(
        '/settings/DEFAULT_ISSUED_AT',
        data: {'value': issuedAt},
      );
      _notify('Default settings saved');
    } catch (e) {
      _notify('Failed to save defaults: $e', isError: true);
    } finally {
      if (mounted) setState(() => _defaultsSaving = false);
    }
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : null,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                icon: Icons.tag,
                title: 'Document Code Settings',
                subtitle: 'Codes are saved and auto-increment for new documents',
                trailing: Icon(Icons.refresh, size: 20),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _buildDefaultsCard(),
              const SizedBox(height: AppTheme.spaceLg),
              ..._settings.map(_buildSettingCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document Defaults',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: _coordinatorController,
              decoration: const InputDecoration(
                labelText: 'Coordinator Name',
                isDense: true,
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Coordinator Title',
                isDense: true,
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: _campusController,
              decoration: const InputDecoration(
                labelText: 'Campus',
                isDense: true,
                prefixIcon: Icon(Icons.school_outlined, size: 20),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: _issuedAtController,
              decoration: const InputDecoration(
                labelText: 'Issued At',
                isDense: true,
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: _defaultsSaving ? null : _saveDefaults,
                  icon: _defaultsSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_defaultsSaving ? 'Saving...' : 'Save Defaults'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(_CodeSetting setting) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Wrap(
              spacing: AppTheme.spaceMd,
              runSpacing: AppTheme.spaceMd,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: setting.prefix,
                    decoration: const InputDecoration(
                      labelText: 'Prefix',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: setting.nextNumber,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Next No.',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: setting.activeYear,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Active Year',
                      hintText: 'current',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: setting.padding,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Padding',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(
                        text: '${setting.effectiveYear}'),
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility, size: 18, color: AppTheme.success),
                        const SizedBox(width: 8),
                        Text(
                          'Next code: ${setting.previewCode}',
                          style: const TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                FilledButton.icon(
                  onPressed: setting.saving ? null : () => _save(setting),
                  icon: setting.saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(setting.saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
