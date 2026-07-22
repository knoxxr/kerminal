import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/host.dart';
import 'symmetric_crypto.dart';

/// The full, decrypted representation of a host as it travels to/from the
/// cloud: non-secret metadata plus its secret material. This is the plaintext
/// that [HostCodec] encrypts under a per-host content key; the server only ever
/// stores the ciphertext.
class HostPayload {
  const HostPayload({
    required this.label,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authMethod,
    this.groupName,
    this.password,
    this.privateKeyPem,
    this.passphrase,
  });

  final String label;
  final String hostname;
  final int port;
  final String username;
  final AuthMethod authMethod;
  final String? groupName;
  final String? password;
  final String? privateKeyPem;
  final String? passphrase;

  Map<String, dynamic> toJson() => {
    'label': label,
    'hostname': hostname,
    'port': port,
    'username': username,
    'authMethod': authMethod.name,
    'groupName': groupName,
    'password': password,
    'privateKeyPem': privateKeyPem,
    'passphrase': passphrase,
  };

  factory HostPayload.fromJson(Map<String, dynamic> j) => HostPayload(
    label: j['label'] as String? ?? '',
    hostname: j['hostname'] as String? ?? '',
    port: (j['port'] as num?)?.toInt() ?? 22,
    username: j['username'] as String? ?? '',
    authMethod: j['authMethod'] == 'sshKey'
        ? AuthMethod.sshKey
        : AuthMethod.password,
    groupName: j['groupName'] as String?,
    password: j['password'] as String?,
    privateKeyPem: j['privateKeyPem'] as String?,
    passphrase: j['passphrase'] as String?,
  );
}

/// Encrypts/decrypts a [HostPayload] with a host's symmetric content key.
class HostCodec {
  const HostCodec._();

  static String encrypt(HostPayload payload, Uint8List contentKey) =>
      SymmetricCrypto.encrypt(jsonEncode(payload.toJson()), contentKey);

  static HostPayload decrypt(String ciphertext, Uint8List contentKey) =>
      HostPayload.fromJson(
        jsonDecode(SymmetricCrypto.decrypt(ciphertext, contentKey))
            as Map<String, dynamic>,
      );
}
