import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Passphrase-based authenticated encryption for host backups.
///
/// Key derivation: PBKDF2-HMAC-SHA256. Cipher: AES-256-GCM (authenticated, so
/// a wrong passphrase or tampering fails decryption). Output is a self-
/// describing JSON envelope (salt + nonce + ciphertext, all base64).
class BackupCrypto {
  static const _iterations = 120000;
  static const _keyLength = 32; // AES-256
  static const _saltLength = 16;
  static const _nonceLength = 12; // GCM standard
  static const _macBits = 128;

  static final _random = Random.secure();

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _random.nextInt(256)));

  static Uint8List _deriveKey(String passphrase, Uint8List salt, int iterations) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, _keyLength));
    return kdf.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Encrypts [plaintext] under [passphrase], returning a JSON envelope string.
  static String encrypt(String plaintext, String passphrase) {
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = _deriveKey(passphrase, salt, _iterations);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true,
          AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)));
    final ciphertext =
        cipher.process(Uint8List.fromList(utf8.encode(plaintext)));

    return jsonEncode({
      'format': 'kerminal-backup',
      'version': 1,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _iterations,
      'cipher': 'aes-256-gcm',
      'salt': base64.encode(salt),
      'nonce': base64.encode(nonce),
      'ciphertext': base64.encode(ciphertext),
    });
  }

  /// Decrypts a JSON envelope produced by [encrypt]. Throws if the passphrase
  /// is wrong or the data is corrupt/tampered (GCM authentication failure).
  static String decrypt(String envelope, String passphrase) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(envelope) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Not a valid backup file.');
    }
    if (j['format'] != 'kerminal-backup') {
      throw const FormatException('Not a Kerminal backup file.');
    }
    final salt = Uint8List.fromList(base64.decode(j['salt'] as String));
    final nonce = Uint8List.fromList(base64.decode(j['nonce'] as String));
    final ciphertext =
        Uint8List.fromList(base64.decode(j['ciphertext'] as String));
    final iterations = (j['iterations'] as int?) ?? _iterations;
    final key = _deriveKey(passphrase, salt, iterations);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false,
          AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)));
    // Throws InvalidCipherTextException when the passphrase is wrong.
    final plaintext = cipher.process(ciphertext);
    return utf8.decode(plaintext);
  }
}

/// Thrown for a wrong passphrase or corrupt backup.
class BackupDecryptException implements Exception {
  const BackupDecryptException();
  @override
  String toString() => 'Wrong passphrase or corrupt backup file.';
}
