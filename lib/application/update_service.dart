import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

/// Result of an update check.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    this.notes,
    this.downloadUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final String? notes;

  /// Platform-appropriate download URL for the latest release, if provided.
  final String? downloadUrl;
}

/// Checks a remote version manifest (a `latest.json`) and compares it against
/// the running app version. The manifest format:
///
/// ```json
/// {
///   "version": "0.2.0",
///   "notes": "What changed...",
///   "downloads": {
///     "windows": "https://.../kominal-0.2.0.msix",
///     "macos":   "https://.../kominal-0.2.0.dmg",
///     "linux":   "https://.../kominal-0.2.0.AppImage",
///     "android": "https://.../kominal-0.2.0.apk"
///   }
/// }
/// ```
class UpdateService {
  UpdateService({
    required this.client,
    required this.manifestUrl,
    required this.currentVersion,
    this.timeout = const Duration(seconds: 8),
  });

  final http.Client client;
  final Uri manifestUrl;
  final String currentVersion;
  final Duration timeout;

  Future<UpdateInfo> check() async {
    final response = await client.get(manifestUrl).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Manifest fetch failed (${response.statusCode})',
        manifestUrl,
      );
    }
    return parseManifest(response.body);
  }

  /// Parses a manifest body against [currentVersion]. Exposed for testing.
  UpdateInfo parseManifest(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final latest = (json['version'] as String).trim();
    final notes = json['notes'] as String?;
    final downloads = (json['downloads'] as Map?)?.cast<String, dynamic>();

    final available = Version.parse(latest) > Version.parse(currentVersion);

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latest,
      updateAvailable: available,
      notes: notes,
      downloadUrl: _platformDownload(downloads),
    );
  }

  String? _platformDownload(Map<String, dynamic>? downloads) {
    if (downloads == null) return null;
    final key = _platformKey();
    return downloads[key] as String?;
  }

  String _platformKey() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }
}
