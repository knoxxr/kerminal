import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart';

/// A freshly generated SSH key pair.
class GeneratedKey {
  const GeneratedKey({required this.privateKeyPem, required this.publicKeyLine});

  /// OpenSSH-format PEM to store in the vault and use for authentication.
  final String privateKeyPem;

  /// `authorized_keys` line to install on the server.
  final String publicKeyLine;
}

/// Generates SSH key pairs. Ed25519 only (modern, compact, well supported).
class SshKeyGenerator {
  const SshKeyGenerator();

  /// Generates an unencrypted Ed25519 key pair.
  ///
  /// pinenacl's [SigningKey] stores the 64-byte `seed || publicKey` secret,
  /// which is exactly the OpenSSH Ed25519 private-key representation, so it
  /// feeds [OpenSSHEd25519KeyPair] directly.
  GeneratedKey generateEd25519({String comment = 'kominal'}) {
    final signing = SigningKey.generate();
    final publicKey = Uint8List.fromList(signing.verifyKey.asTypedList);
    final privateKey = Uint8List.fromList(signing.asTypedList); // 64 bytes

    final keyPair = OpenSSHEd25519KeyPair(publicKey, privateKey, comment);
    final blob = keyPair.toPublicKey().encode();
    final line = 'ssh-ed25519 ${base64.encode(blob)} $comment';

    return GeneratedKey(
      privateKeyPem: keyPair.toPem(),
      publicKeyLine: line,
    );
  }
}
