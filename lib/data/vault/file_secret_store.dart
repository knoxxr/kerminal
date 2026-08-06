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
/// directory, with the key in a sibling file. This is weaker than the OS
/// keychain but is the pragmatic option on macOS without an Apple Developer
/// signing identity.
class FileSecretStore implements SecretStore {
  FileSecretStore();

  Map<String, String>? _cache;
  Uint8List? _key;
  File? _dataFile;
  File? _keyFile;

  /// In-flight load, so concurrent callers share one initialization.
  ///
  /// Without this, two overlapping calls could each decide the key file is
  /// missing and generate one — the second overwriting the first, leaving the
  /// already-written data undecryptable.
  Future<void>? _loading;

  /// Serializes writes so two concurrent [_persist] calls cannot interleave and
  /// produce a truncated or mixed file.
  Future<void> _writeQueue = Future<void>.value();

  Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    _loading ??= _load();
    try {
      await _loading;
    } finally {
      // A failed load must not be cached, or every later call fails with it.
      if (_cache == null) _loading = null;
    }
  }

  Future<void> _load() async {
    final dir = await getApplicationSupportDirectory();
    final keyFile = File(p.join(dir.path, 'vault.key'));
    final dataFile = File(p.join(dir.path, 'vault.enc'));
    _keyFile = keyFile;
    _dataFile = dataFile;

    if (await keyFile.exists()) {
      _key = base64.decode((await keyFile.readAsString()).trim());
    } else {
      _key = SymmetricCrypto.randomKey();
      await keyFile.writeAsString(base64.encode(_key!), flush: true);
      await _restrictPermissions(keyFile);
    }

    if (!await dataFile.exists()) {
      _cache = <String, String>{};
      return;
    }
    try {
      final plain = SymmetricCrypto.decrypt(
        await dataFile.readAsString(),
        _key!,
      );
      _cache = (jsonDecode(plain) as Map).cast<String, String>();
    } catch (e) {
      // The data is there but unreadable (key lost, file corrupt). Starting
      // with an empty cache is the only way to keep working — but the next
      // write would overwrite the file and destroy any chance of recovery, so
      // move the original aside first.
      final saved = await _preserveUnreadable(dataFile);
      debugPrint(
        'kerminal: could not decrypt the secret vault ($e). '
        'The unreadable file was kept at ${saved?.path ?? 'its original path'}; '
        'saved passwords and keys must be re-entered or restored from a backup.',
      );
      _cache = <String, String>{};
    }
  }

  /// Renames an undecryptable vault to a free `vault.enc.unreadable-N` slot so
  /// nothing is lost, and returns the new location.
  Future<File?> _preserveUnreadable(File dataFile) async {
    try {
      for (var i = 0;; i++) {
        final candidate = File('${dataFile.path}.unreadable${i == 0 ? '' : '-$i'}');
        if (await candidate.exists()) continue;
        return await dataFile.rename(candidate.path);
      }
    } catch (_) {
      // Could not move it; leave the original in place rather than risk losing
      // it. _persist below will overwrite, which is the pre-existing behavior.
      return null;
    }
  }

  /// Best-effort `chmod 600`. Dart cannot set a file mode directly, and these
  /// files hold SSH private keys, so it is worth the one-off process spawn.
  Future<void> _restrictPermissions(File file) async {
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', ['600', file.path]);
    } catch (_) {/* not fatal — the directory is already user-scoped */}
  }

  Future<void> _persist() {
    final cache = Map<String, String>.from(_cache!);
    final file = _dataFile!;
    final key = _key!;
    return _writeQueue = _writeQueue.then((_) async {
      final created = !await file.exists();
      await file.writeAsString(
        SymmetricCrypto.encrypt(jsonEncode(cache), key),
        flush: true,
      );
      if (created) await _restrictPermissions(file);
    });
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
