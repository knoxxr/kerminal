import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'update_service.dart';

/// Where the app looks for its release manifest. Defaults to the GitHub
/// "latest release" asset, which always resolves to the newest published
/// release's `latest.json`. Override at build time with
/// `--dart-define=UPDATE_MANIFEST_URL=...` (empty disables the check).
const kUpdateManifestUrl = String.fromEnvironment(
  'UPDATE_MANIFEST_URL',
  defaultValue:
      'https://github.com/knoxxr/kerminal/releases/latest/download/latest.json',
);

/// The manifest URL as a provider so it can be overridden in tests.
final updateManifestUrlProvider = Provider<String>((ref) => kUpdateManifestUrl);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Checks for an available update. Returns null only when no manifest URL is
/// configured (the check is disabled). Network/parse failures are allowed to
/// propagate so the UI can surface them via the provider's error state —
/// swallowing them here makes a failed check indistinguishable from "no update"
/// and looks like the button does nothing. Re-run with
/// `ref.invalidate(updateCheckProvider)`.
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final url = ref.watch(updateManifestUrlProvider);
  if (url.isEmpty) return null;

  final info = await ref.watch(packageInfoProvider.future);
  final service = UpdateService(
    client: ref.watch(httpClientProvider),
    manifestUrl: Uri.parse(url),
    currentVersion: info.version,
  );
  return service.check();
});
