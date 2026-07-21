import 'package:uuid/uuid.dart';

import '../core/os_user.dart';
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
}
