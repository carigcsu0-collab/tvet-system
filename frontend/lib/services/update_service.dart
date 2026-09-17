import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:version/version.dart';

/// Checks GitHub Releases for a newer version of the app and, if the user
/// accepts, downloads and launches the platform-appropriate installer:
/// - Android: the `.apk` release asset (opened via the system package installer)
/// - Windows: the Inno Setup installer produced by `release.iss`
///   (OutputBaseFilename = `tvet_documents_setup`, i.e. `tvet_documents_setup.exe`)
class UpdateService {
  UpdateService._();

  static const String _githubOwner = 'carigcsu0-collab';
  static const String _githubRepo = 'tvet-system';
  static const String _windowsInstallerName = 'tvet_documents_setup.exe';

  static Uri get _latestReleaseUri => Uri.parse(
      'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest');

  /// Fetches the latest GitHub release and, if it is newer than the
  /// currently installed version, shows a dialog offering to download and
  /// install it. Safe to call from `initState` — all errors are swallowed
  /// since update checks should never block or crash the app.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    try {
      final release = await _fetchLatestRelease();
      if (release == null) return;

      final latestVersion = _parseVersion(release['tag_name']?.toString());
      if (latestVersion == null) return;

      final info = await PackageInfo.fromPlatform();
      final currentVersion = _parseVersion(info.version);
      if (currentVersion == null) return;

      if (latestVersion <= currentVersion) return;

      final assets = (release['assets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final asset = Platform.isAndroid
          ? _findAsset(assets, (name) => name.endsWith('.apk'))
          : _findAsset(
              assets,
              (name) =>
                  name == _windowsInstallerName ||
                  name.endsWith('.exe') ||
                  name.endsWith('.msi'));
      if (asset == null) return;

      final downloadUrl = asset['browser_download_url']?.toString();
      final assetName = asset['name']?.toString();
      if (downloadUrl == null || assetName == null) return;

      if (!context.mounted) return;
      final shouldUpdate = await _showUpdateDialog(
        context,
        currentVersion: info.version,
        latestVersion: latestVersion.toString(),
        notes: release['body']?.toString(),
      );
      if (shouldUpdate != true) return;
      if (!context.mounted) return;

      await _downloadAndInstall(context, downloadUrl, assetName);
    } catch (_) {
      // Never let update checks disrupt normal app usage.
    }
  }

  static Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    final response = await http
        .get(_latestReleaseUri, headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Version? _parseVersion(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final cleaned = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    // Strip build metadata like "+3" (Flutter's version format) which the
    // `version` package does not accept.
    final withoutBuild = cleaned.split('+').first;
    try {
      return Version.parse(withoutBuild);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _findAsset(
      List<Map<String, dynamic>> assets, bool Function(String name) matches) {
    for (final asset in assets) {
      final name = asset['name']?.toString().toLowerCase();
      if (name != null && matches(name)) return asset;
    }
    return null;
  }

  static Future<bool?> _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    String? notes,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version ($latestVersion) is available. '
                'You are currently using $currentVersion.'),
            if (notes != null && notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text("What's new:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(child: Text(notes.trim())),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(
      BuildContext context, String url, String fileName) async {
    final progress = ValueNotifier<double?>(0);
    if (!context.mounted) return;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Downloading Update'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              Text(value == null ? 'Starting...' : '${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    ));

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      final total = response.contentLength ?? 0;
      var received = 0;
      final file = File(filePath);
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) progress.value = received / total;
      }
      await sink.close();

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await OpenFilex.open(filePath);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update download failed: $e')),
        );
      }
    }
  }
}
