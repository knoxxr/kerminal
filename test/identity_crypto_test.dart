import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/data/crypto/backup_crypto.dart';
import 'package:kerminal/data/crypto/identity_crypto.dart';

void main() {
  test('generate produces 32-byte keys and a matching public key', () {
    final kp = IdentityCrypto.generate();
    expect(kp.privateKey.length, 32);
    expect(kp.publicKey.length, 32);
    // The public key must be the one derived from the private key.
    expect(IdentityCrypto.publicKeyOf(kp.privateKey), kp.publicKey);
  });

  test('each generated key pair is unique', () {
    final a = IdentityCrypto.generate();
    final b = IdentityCrypto.generate();
    expect(a.privateKey, isNot(b.privateKey));
  });

  test('wrap/unwrap round-trips the private key with the right passphrase', () {
    final kp = IdentityCrypto.generate();
    final wrapped = IdentityCrypto.wrapPrivateKey(kp.privateKey, 'correct horse');
    final restored = IdentityCrypto.unwrapPrivateKey(wrapped, 'correct horse');
    expect(restored, kp.privateKey);
  });

  test('unwrap with a wrong passphrase fails authentication', () {
    final kp = IdentityCrypto.generate();
    final wrapped = IdentityCrypto.wrapPrivateKey(kp.privateKey, 'right');
    expect(
      () => IdentityCrypto.unwrapPrivateKey(wrapped, 'wrong'),
      throwsA(anything),
    );
  });

  test('seal/unseal round-trips a message for the intended recipient', () {
    final recipient = IdentityCrypto.generate();
    final message = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

    final sealed = IdentityCrypto.seal(message, recipient.publicKey);
    final opened = IdentityCrypto.unseal(sealed, recipient.privateKey);
    expect(opened, message);
  });

  test('a different account cannot open a sealed message', () {
    final recipient = IdentityCrypto.generate();
    final attacker = IdentityCrypto.generate();
    final sealed = IdentityCrypto.seal(
      Uint8List.fromList([9, 9, 9]),
      recipient.publicKey,
    );
    expect(
      () => IdentityCrypto.unseal(sealed, attacker.privateKey),
      throwsA(anything),
    );
  });

  test('wrapped private key is a Kerminal encryption envelope', () {
    // Sanity: the wrapper reuses BackupCrypto, so BackupCrypto can read it.
    final kp = IdentityCrypto.generate();
    final wrapped = IdentityCrypto.wrapPrivateKey(kp.privateKey, 'pw');
    expect(BackupCrypto.decrypt(wrapped, 'pw'), isNotEmpty);
  });
}
