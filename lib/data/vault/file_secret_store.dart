import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/symmetric_crypto.dart';
import 'secure_vault.dart';

/// Returns a [FileSecretStore] on macOS, else null (use the OS keychain).
///
/// macOS ad-hoc-signed (non-App-Store) builds cannot use the keychain: access
/// fails with errSecMissingEntitlement (-34018), and adding the required
/// `keychain-access-groups` entitlement makes macOS refuse to launch the app.
SecretStore? macosSecretStore() =>
    defaultTargetPlatform == TargetPlatform.macOS ? FileSecretStore() : null;

/// Secrets kept in an AES-256-GCM-encrypted file under the app-support
/// directory. The key sits next to the data (both 0600-ish, app-private). This
/// is weaker than the OS keychain but is the pragmatic option on macOS without
/// an Apple Developer signing identity.
class FileSecretStore implements SecretStore {
  FileSecretStore();

  Map<String, String>? _cache;
  Uint8List? _key;
  late final File _dataFile;
  late final File _keyFile;

  Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    final dir = await getApplicationSupportDirectory();
    _keyFile = File(p.join(dir.path, 'vault.key'));
    _dataFile = File(p.join(dir.path, 'vault.enc'));

    if (await _keyFile.exists()) {
      _key = base64.decode((await _keyFile.readAsString()).trim());
    } else {
      _key = SymmetricCrypto.randomKey();
      await _keyFile.writeAsString(base64.encode(_key!), flush: true);
    }

    if (await _dataFile.exists()) {
      try {
        final plain = SymmetricCrypto.decrypt(
          await _dataFile.readAsString(),
          _key!,
        );
        _cache = (jsonDecode(plain) as Map).cast<String, String>();
      } catch (_) {
        _cache = <String, String>{};
      }
    } else {
      _cache = <String, String>{};
    }
  }

  Future<void> _persist() async {
    await _dataFile.writeAsString(
      SymmetricCrypto.encrypt(jsonEncode(_cache), _key!),
      flush: true,
    );
  }

  @override
  Future<void> write(String key, String value) async {
    await _ensureLoaded();
    _cache![key] = value;
    await _persist();
  }

  @override
  Future<String?> read(String key) async {
    await _ensureLoaded();
    return _cache![key];
  }

  @override
  Future<void> delete(String key) async {
    await _ensureLoaded();
    _cache!.remove(key);
    await _persist();
  }
}
