import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Raw-key authenticated encryption (AES-256-GCM) for per-host content keys.
///
/// Unlike [BackupCrypto], which derives a key from a passphrase, this operates
/// on a 32-byte key directly — the random content key that a host is encrypted
/// with and that gets sealed to each authorized account's public key. Output is
/// a self-describing JSON envelope (nonce + ciphertext, base64).
class SymmetricCrypto {
  static const keyLength = 32; // AES-256
  static const _nonceLength = 12; // GCM standard
  static const _macBits = 128;

  static final _random = Random.secure();

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _random.nextInt(256)));

  /// A fresh random 32-byte content key.
  static Uint8List randomKey() => _randomBytes(keyLength);

  /// Encrypts [plaintext] under a raw 32-byte [key].
  static String encrypt(String plaintext, Uint8List key) {
    final nonce = _randomBytes(_nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)),
      );
    final ciphertext = cipher.process(
      Uint8List.fromList(utf8.encode(plaintext)),
    );
    return jsonEncode({
      'v': 1,
      'cipher': 'aes-256-gcm',
      'nonce': base64.encode(nonce),
      'ciphertext': base64.encode(ciphertext),
    });
  }

  /// Reverses [encrypt]. Throws when the key is wrong or the data was tampered
  /// with (GCM authentication failure).
  static String decrypt(String envelope, Uint8List key) {
    final j = jsonDecode(envelope) as Map<String, dynamic>;
    final nonce = Uint8List.fromList(base64.decode(j['nonce'] as String));
    final ciphertext = Uint8List.fromList(
      base64.decode(j['ciphertext'] as String),
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)),
      );
    return utf8.decode(cipher.process(ciphertext));
  }
}
