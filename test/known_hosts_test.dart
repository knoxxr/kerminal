import 'package:flutter_test/flutter_test.dart';
import 'package:kominal/application/known_hosts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<KnownHostsService> makeService() async {
    SharedPreferences.setMockInitialValues({});
    return KnownHostsService(await SharedPreferences.getInstance());
  }

  test('unknown host, then matched after trust', () async {
    final svc = await makeService();
    const fp = 'SHA256:abc123';

    expect(svc.check('h', 22, fp), HostKeyStatus.unknown);
    await svc.trust('h', 22, fp);
    expect(svc.check('h', 22, fp), HostKeyStatus.matched);
    expect(svc.fingerprintFor('h', 22), fp);
  });

  test('changed fingerprint is detected', () async {
    final svc = await makeService();
    await svc.trust('h', 22, 'SHA256:original');
    expect(svc.check('h', 22, 'SHA256:different'), HostKeyStatus.changed);
  });

  test('port is part of the identity', () async {
    final svc = await makeService();
    await svc.trust('h', 22, 'SHA256:a');
    expect(svc.check('h', 2222, 'SHA256:a'), HostKeyStatus.unknown);
  });

  test('forget removes a trusted host', () async {
    final svc = await makeService();
    await svc.trust('h', 22, 'SHA256:a');
    await svc.forget('h', 22);
    expect(svc.check('h', 22, 'SHA256:a'), HostKeyStatus.unknown);
  });
}
