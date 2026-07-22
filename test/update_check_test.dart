import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kerminal/application/update_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _pkg(String version) => PackageInfo(
      appName: 'Kerminal',
      packageName: 'kr.smic.kerminal',
      version: version,
      buildNumber: '1',
    );

const _manifest =
    '{"version":"0.2.0","notes":"New stuff","downloads":{"windows":"https://x/kerminal.msix","android":"https://x/kerminal.apk"}}';

ProviderContainer _container({
  required String currentVersion,
  String url = 'https://example.com/latest.json',
  MockClient? client,
}) {
  return ProviderContainer(overrides: [
    updateManifestUrlProvider.overrideWithValue(url),
    packageInfoProvider.overrideWith((ref) async => _pkg(currentVersion)),
    if (client != null) httpClientProvider.overrideWithValue(client),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Check surfaces an available update', () async {
    final c = _container(
      currentVersion: '0.1.2',
      client: MockClient((_) async => http.Response(_manifest, 200)),
    );
    addTearDown(c.dispose);

    final info = await c.read(updateCheckProvider.future);
    expect(info, isNotNull);
    expect(info!.updateAvailable, isTrue);
    expect(info.latestVersion, '0.2.0');
    expect(info.notes, 'New stuff');
    // Platform-appropriate download URL (android in the test VM).
    expect(info.downloadUrl, contains('kerminal'));
  });

  test('Check reports up-to-date when versions match', () async {
    final c = _container(
      currentVersion: '0.2.0',
      client: MockClient((_) async => http.Response(_manifest, 200)),
    );
    addTearDown(c.dispose);

    final info = await c.read(updateCheckProvider.future);
    expect(info, isNotNull);
    expect(info!.updateAvailable, isFalse);
  });

  test('no manifest URL configured => check disabled (null)', () async {
    final c = _container(currentVersion: '0.1.2', url: '');
    addTearDown(c.dispose);
    expect(await c.read(updateCheckProvider.future), isNull);
  });

  test('unreachable/failed manifest => error propagates (visible to UI)',
      () async {
    final c = _container(
      currentVersion: '0.1.2',
      client: MockClient((_) async => http.Response('not found', 404)),
    );
    addTearDown(c.dispose);
    // Keep the provider alive while its async build settles, then assert it
    // surfaced an error rather than a silent null — otherwise the UI can't
    // tell "no update" from "check failed".
    c.listen(updateCheckProvider, (_, _) {}, fireImmediately: true);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final state = c.read(updateCheckProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<http.ClientException>());
  });
}
