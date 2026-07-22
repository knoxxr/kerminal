import 'dart:convert';

import 'package:pinenacl/x25519.dart';

import 'backup_crypto.dart';

/// An X25519 key pair identifying a Kerminal account.
///
/// The private key never leaves the device in the clear: only [publicKey] and a
/// passphrase-wrapped copy of [privateKey] (see [IdentityCrypto.wrapPrivateKey])
/// are stored in the cloud. Both keys are 32 bytes.
class IdentityKeyPair {
  const IdentityKeyPair({required this.privateKey, required this.publicKey});

  final Uint8List privateKey;
  final Uint8List publicKey;
}

/// Public-key cryptography for account identities and host sharing.
///
/// Uses NaCl (Curve25519): each account has an X25519 key pair; a host's
/// symmetric content key is sealed to each authorized account's public key with
/// `crypto_box_seal` so only the holder of the matching private key can open it.
/// The private key itself is wrapped with the user's passphrase (PBKDF2 +
/// AES-256-GCM, reusing [BackupCrypto]) for storage/backup.
class IdentityCrypto {
  const IdentityCrypto._();

  /// Generates a fresh account key pair.
  static IdentityKeyPair generate() {
    final sk = PrivateKey.generate();
    return IdentityKeyPair(
      privateKey: Uint8List.fromList(sk.asTypedList),
      publicKey: Uint8List.fromList(sk.publicKey.asTypedList),
    );
  }

  /// Derives the public key for a raw 32-byte [privateKey].
  static Uint8List publicKeyOf(Uint8List privateKey) =>
      Uint8List.fromList(PrivateKey(privateKey).publicKey.asTypedList);

  /// Wraps [privateKey] under [passphrase] into a portable JSON envelope safe to
  /// store in the cloud.
  static String wrapPrivateKey(Uint8List privateKey, String passphrase) =>
      BackupCrypto.encrypt(base64.encode(privateKey), passphrase);

  /// Reverses [wrapPrivateKey]. Throws when the passphrase is wrong or the data
  /// was tampered with (GCM authentication failure).
  static Uint8List unwrapPrivateKey(String wrapped, String passphrase) =>
      Uint8List.fromList(
        base64.decode(BackupCrypto.decrypt(wrapped, passphrase)),
      );

  /// Seals [message] so that only the holder of [recipientPublicKey]'s private
  /// key can open it (anonymous sender). Used to share host content keys.
  static Uint8List seal(Uint8List message, Uint8List recipientPublicKey) =>
      Uint8List.fromList(
        SealedBox(PublicKey(recipientPublicKey)).encrypt(message),
      );

  /// Opens a [sealed] message addressed to the holder of [privateKey].
  static Uint8List unseal(Uint8List sealed, Uint8List privateKey) =>
      Uint8List.fromList(SealedBox(PrivateKey(privateKey)).decrypt(sealed));
}
