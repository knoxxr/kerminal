import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/application/known_hosts.dart';
import 'package:kerminal/data/crypto/backup_crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BackupCrypto.decrypt rejects hostile envelopes', () {
    test('an absurd iteration count is refused instead of run', () {
      // Left unchecked this hangs the app: PBKDF2 would run the claimed number
      // of rounds before failing.
      final envelope = BackupCrypto.encrypt('{"hosts":[]}', 'pw')
          .replaceFirst('"iterations":120000', '"iterations":2000000000');
      expect(
        () => BackupCrypto.decrypt(envelope, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a zero iteration count is refused', () {
      final envelope = BackupCrypto.encrypt('{"hosts":[]}', 'pw')
          .replaceFirst('"iterations":120000', '"iterations":0');
      expect(
        () => BackupCrypto.decrypt(envelope, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('an unknown cipher is refused rather than silently misread', () {
      final envelope = BackupCrypto.encrypt('{"hosts":[]}', 'pw')
          .replaceFirst('"cipher":"aes-256-gcm"', '"cipher":"rot13"');
      expect(
        () => BackupCrypto.decrypt(envelope, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a well-formed envelope still round-trips', () {
      final envelope = BackupCrypto.encrypt('{"hosts":[]}', 'pw');
      expect(BackupCrypto.decrypt(envelope, 'pw'), '{"hosts":[]}');
    });
  });

  group('KnownHostsService survives a damaged store', () {
    test('corrupt JSON reads as "no known hosts", not an exception', () async {
      // Throwing here would propagate through the host-key verifier and make
      // connecting to anything impossible.
      SharedPreferences.setMockInitialValues({'known_hosts': 'not json at all'});
      final service = KnownHostsService(await SharedPreferences.getInstance());

      expect(service.fingerprintFor('example.com', 22), isNull);
      expect(
        service.check('example.com', 22, 'SHA256:abc'),
        HostKeyStatus.unknown,
      );
    });

    test('non-string entries are dropped, valid ones kept', () async {
      SharedPreferences.setMockInitialValues({
        'known_hosts': '{"a:22":"SHA256:aaa","b:22":42}',
      });
      final service = KnownHostsService(await SharedPreferences.getInstance());

      expect(service.check('a', 22, 'SHA256:aaa'), HostKeyStatus.matched);
      expect(service.check('b', 22, 'SHA256:bbb'), HostKeyStatus.unknown);
    });

    test('trust still works after recovering from a corrupt store', () async {
      SharedPreferences.setMockInitialValues({'known_hosts': '['});
      final service = KnownHostsService(await SharedPreferences.getInstance());

      await service.trust('example.com', 22, 'SHA256:xyz');
      expect(
        service.check('example.com', 22, 'SHA256:xyz'),
        HostKeyStatus.matched,
      );
    });
  });
}
