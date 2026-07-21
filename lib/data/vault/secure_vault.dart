import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over [FlutterSecureStorage] for storing SSH secrets
/// (passwords and private keys) in the OS-backed keychain/keystore.
///
/// Secrets are keyed by an opaque `credentialId` that the [Host] metadata
/// references. Nothing secret ever touches the plain-text database.
class SecureVault {
  SecureVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String credentialId) => 'cred:$credentialId';

  Future<void> writeSecret(String credentialId, String secret) =>
      _storage.write(key: _key(credentialId), value: secret);

  Future<String?> readSecret(String credentialId) =>
      _storage.read(key: _key(credentialId));

  Future<void> deleteSecret(String credentialId) =>
      _storage.delete(key: _key(credentialId));
}
