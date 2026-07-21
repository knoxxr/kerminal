import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kerminal/application/update_service.dart';

UpdateService _service(String current) => UpdateService(
      client: http.Client(),
      manifestUrl: Uri.parse('https://example.com/latest.json'),
      currentVersion: current,
    );

const _manifest = '''
{
  "version": "0.2.0",
  "notes": "New stuff",
  "downloads": {
    "windows": "https://example.com/kerminal-0.2.0.msix",
    "android": "https://example.com/kerminal-0.2.0.apk"
  }
}
''';

void main() {
  test('detects a newer version', () {
    final info = _service('0.1.0').parseManifest(_manifest);
    expect(info.updateAvailable, isTrue);
    expect(info.latestVersion, '0.2.0');
    expect(info.notes, 'New stuff');
  });

  test('no update when already latest', () {
    final info = _service('0.2.0').parseManifest(_manifest);
    expect(info.updateAvailable, isFalse);
  });

  test('no update when newer than remote', () {
    final info = _service('0.3.0').parseManifest(_manifest);
    expect(info.updateAvailable, isFalse);
  });

  test('picks the platform-specific download url', () {
    // In the test VM, defaultTargetPlatform is android.
    final info = _service('0.1.0').parseManifest(_manifest);
    expect(info.downloadUrl, 'https://example.com/kerminal-0.2.0.apk');
  });

  test('handles a manifest without downloads', () {
    final info = _service('0.1.0').parseManifest('{"version": "1.0.0"}');
    expect(info.updateAvailable, isTrue);
    expect(info.downloadUrl, isNull);
  });
}
