import 'dart:convert';

import 'package:pointycastle/export.dart' show InvalidCipherTextException;
import 'package:uuid/uuid.dart';

import '../core/os_user.dart';
import '../data/crypto/backup_crypto.dart';
import '../data/vault/secure_vault.dart';
import '../domain/entities/host.dart';
import '../domain/entities/ssh_connection_request.dart';
import '../domain/repositories/host_repository.dart';

/// Coordinates host metadata (in the DB) with its secret material (in the
/// secure vault). This is the only place that knows the secret-key layout, so
/// the rest of the app never touches raw secrets.
class HostService {
  HostService(this._repo, this._vault, {this._uuid = const Uuid()});

  final HostRepository _repo;
  final SecureVault _vault;
  final Uuid _uuid;

  String _pwKey(String cid) => '$cid/password';
  String _keyKey(String cid) => '$cid/privateKey';
  String _passKey(String cid) => '$cid/passphrase';

  /// Creates or updates a host and stores its secret in the vault.
  ///
  /// On edit, an empty [password]/[privateKeyPem] leaves the existing secret
  /// untouched (so the user need not re-enter it just to rename a host).
  Future<Host> saveHost({
    Host? existing,
    required String label,
    required String hostname,
    required int port,
    required String username,
    String? groupName,
    required AuthMethod authMethod,
    String? password,
    String? privateKeyPem,
    String? passphrase,
  }) async {
    final id = existing?.id ?? _uuid.v4();
    final credentialId = existing?.credentialId ?? id;

    final hasNewSecret = authMethod == AuthMethod.password
        ? (password?.isNotEmpty ?? false)
        : (privateKeyPem?.isNotEmpty ?? false);

    if (hasNewSecret) {
      await _clearSecrets(credentialId);
      if (authMethod == AuthMethod.password) {
        await _vault.writeSecret(_pwKey(credentialId), password!);
      } else {
        await _vault.writeSecret(_keyKey(credentialId), privateKeyPem!);
        if (passphrase?.isNotEmpty ?? false) {
          await _vault.writeSecret(_passKey(credentialId), passphrase!);
        }
      }
    }

    final host = Host(
      id: id,
      label: label,
      hostname: hostname,
      port: port,
      username: username,
      authMethod: authMethod,
      groupName:
          (groupName?.trim().isEmpty ?? true) ? kDefaultGroup : groupName!.trim(),
      credentialId: credentialId,
    );
    await _repo.upsertHost(host);
    return host;
  }

  /// Builds a connection request for a saved host, reading its secret from the
  /// vault. The result is transient and never persisted.
  Future<SshConnectionRequest> buildRequest(Host host) async {
    final cid = host.credentialId;
    // Blank account => default to the OS user (like the ssh CLI).
    final username = host.username.isEmpty ? osUsername() : host.username;
    if (host.authMethod == AuthMethod.sshKey) {
      return SshConnectionRequest(
        host: host.hostname,
        port: host.port,
        username: username,
        authKind: SshAuthKind.key,
        privateKeyPem: cid == null ? null : await _vault.readSecret(_keyKey(cid)),
        passphrase: cid == null ? null : await _vault.readSecret(_passKey(cid)),
        label: host.label,
      );
    }
    return SshConnectionRequest(
      host: host.hostname,
      port: host.port,
      username: username,
      authKind: SshAuthKind.password,
      password: cid == null ? null : await _vault.readSecret(_pwKey(cid)),
      label: host.label,
    );
  }

  Future<void> deleteHost(Host host) async {
    if (host.credentialId != null) await _clearSecrets(host.credentialId!);
    await _repo.deleteHost(host.id);
  }

  Future<void> _clearSecrets(String cid) async {
    await _vault.deleteSecret(_pwKey(cid));
    await _vault.deleteSecret(_keyKey(cid));
    await _vault.deleteSecret(_passKey(cid));
  }

  // --- Encrypted backup / sharing ---

  /// Bundles every host (metadata + secrets) and encrypts it with [passphrase].
  /// The result is safe to share (e.g. via Google Drive): without the
  /// passphrase it cannot be decrypted.
  Future<String> exportEncrypted(String passphrase) async {
    final hosts = await _repo.getHosts();
    final items = <Map<String, dynamic>>[];
    for (final h in hosts) {
      final cid = h.credentialId;
      final item = <String, dynamic>{
        'label': h.label,
        'hostname': h.hostname,
        'port': h.port,
        'username': h.username,
        'group': h.groupName,
        'authMethod': h.authMethod.name,
      };
      if (cid != null) {
        if (h.authMethod == AuthMethod.password) {
          item['password'] = await _vault.readSecret(_pwKey(cid));
        } else {
          item['privateKey'] = await _vault.readSecret(_keyKey(cid));
          item['passphrase'] = await _vault.readSecret(_passKey(cid));
        }
      }
      items.add(item);
    }
    final plaintext = jsonEncode({'version': 1, 'hosts': items});
    return BackupCrypto.encrypt(plaintext, passphrase);
  }

  /// Imports hosts from an encrypted backup, adding them as new hosts (secrets
  /// go to the vault). Returns the number imported. Throws
  /// [BackupDecryptException] on a wrong passphrase / corrupt file.
  Future<int> importEncrypted(String envelope, String passphrase) async {
    final String plaintext;
    try {
      plaintext = BackupCrypto.decrypt(envelope, passphrase);
    } on InvalidCipherTextException {
      throw const BackupDecryptException();
    }
    final data = jsonDecode(plaintext) as Map<String, dynamic>;
    final hosts = (data['hosts'] as List).cast<Map<String, dynamic>>();
    for (final h in hosts) {
      await saveHost(
        label: h['label'] as String? ?? 'Imported',
        hostname: h['hostname'] as String? ?? '',
        port: (h['port'] as num?)?.toInt() ?? 22,
        username: h['username'] as String? ?? '',
        groupName: h['group'] as String?,
        authMethod:
            h['authMethod'] == 'sshKey' ? AuthMethod.sshKey : AuthMethod.password,
        password: h['password'] as String?,
        privateKeyPem: h['privateKey'] as String?,
        passphrase: h['passphrase'] as String?,
      );
    }
    return hosts.length;
  }
}
