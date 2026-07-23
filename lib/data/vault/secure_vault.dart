import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Picks a macOS file-based store when appropriate; returns null elsewhere so we
// fall back to the OS keychain/keystore. Web build gets the stub (always null).
import 'file_secret_store.dart'
    if (dart.library.html) 'file_secret_store_web.dart';

/// Minimal key/value backend behind [SecureVault]. Abstracted so tests can
/// inject an in-memory store instead of the platform keychain.
abstract interface class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// [SecretStore] backed by the OS keychain/keystore (Windows Credential
/// Manager, libsecret, Android Keystore, iOS keychain, web storage).
class FlutterSecretStore implements SecretStore {
  const FlutterSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores SSH secrets (passwords and private keys) in the OS-backed secure
/// storage. Secrets are keyed by an opaque id that [Host] metadata references;
/// nothing secret ever touches the plain-text database.
///
/// On macOS the OS keychain is unavailable to ad-hoc-signed (non-App-Store)
/// builds, so secrets go to an encrypted file instead — see
/// [macosSecretStore] / FileSecretStore.
class SecureVault {
  SecureVault([SecretStore? store])
    : _store = store ?? (macosSecretStore() ?? const FlutterSecretStore());

  final SecretStore _store;

  String _key(String credentialId) => 'cred:$credentialId';

  Future<void> writeSecret(String credentialId, String secret) =>
      _store.write(_key(credentialId), secret);

  Future<String?> readSecret(String credentialId) =>
      _store.read(_key(credentialId));

  Future<void> deleteSecret(String credentialId) =>
      _store.delete(_key(credentialId));
}
