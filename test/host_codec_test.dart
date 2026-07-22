import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/data/crypto/host_codec.dart';
import 'package:kerminal/data/crypto/symmetric_crypto.dart';
import 'package:kerminal/domain/entities/host.dart';

void main() {
  group('SymmetricCrypto', () {
    test('round-trips plaintext with the right key', () {
      final key = SymmetricCrypto.randomKey();
      final envelope = SymmetricCrypto.encrypt('hello 세계', key);
      expect(SymmetricCrypto.decrypt(envelope, key), 'hello 세계');
    });

    test('randomKey is 32 bytes', () {
      expect(SymmetricCrypto.randomKey().length, 32);
    });

    test('a wrong key fails authentication', () {
      final envelope = SymmetricCrypto.encrypt('secret', SymmetricCrypto.randomKey());
      expect(
        () => SymmetricCrypto.decrypt(envelope, SymmetricCrypto.randomKey()),
        throwsA(anything),
      );
    });

    test('encryption is randomized (different nonce each time)', () {
      final key = SymmetricCrypto.randomKey();
      expect(
        SymmetricCrypto.encrypt('same', key),
        isNot(SymmetricCrypto.encrypt('same', key)),
      );
    });
  });

  group('HostCodec', () {
    Uint8List key() => SymmetricCrypto.randomKey();

    test('round-trips a password host including its secret', () {
      final k = key();
      const payload = HostPayload(
        label: 'prod',
        hostname: '10.0.0.1',
        port: 2222,
        username: 'root',
        authMethod: AuthMethod.password,
        groupName: 'servers',
        password: 'hunter2',
      );
      final restored = HostCodec.decrypt(HostCodec.encrypt(payload, k), k);
      expect(restored.label, 'prod');
      expect(restored.hostname, '10.0.0.1');
      expect(restored.port, 2222);
      expect(restored.username, 'root');
      expect(restored.authMethod, AuthMethod.password);
      expect(restored.groupName, 'servers');
      expect(restored.password, 'hunter2');
      expect(restored.privateKeyPem, isNull);
    });

    test('round-trips an ssh-key host with passphrase and null group', () {
      final k = key();
      const payload = HostPayload(
        label: 'edge',
        hostname: 'edge.example.com',
        port: 22,
        username: 'deploy',
        authMethod: AuthMethod.sshKey,
        privateKeyPem: '-----BEGIN-----\nabc\n-----END-----',
        passphrase: 'pp',
      );
      final restored = HostCodec.decrypt(HostCodec.encrypt(payload, k), k);
      expect(restored.authMethod, AuthMethod.sshKey);
      expect(restored.privateKeyPem, contains('BEGIN'));
      expect(restored.passphrase, 'pp');
      expect(restored.groupName, isNull);
      expect(restored.password, isNull);
    });

    test('ciphertext does not leak the hostname in the clear', () {
      final k = key();
      const payload = HostPayload(
        label: 'x',
        hostname: 'topsecret.internal',
        port: 22,
        username: 'u',
        authMethod: AuthMethod.password,
      );
      final ciphertext = HostCodec.encrypt(payload, k);
      expect(ciphertext.contains('topsecret'), isFalse);
    });
  });
}
