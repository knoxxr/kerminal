import 'package:flutter_test/flutter_test.dart';
import 'package:kominal/application/host_service.dart';
import 'package:kominal/data/vault/secure_vault.dart';
import 'package:kominal/domain/entities/host.dart';
import 'package:kominal/domain/entities/ssh_connection_request.dart';
import 'package:kominal/domain/repositories/host_repository.dart';

class _MemStore implements SecretStore {
  final Map<String, String> data = {};
  @override
  Future<void> write(String k, String v) async => data[k] = v;
  @override
  Future<String?> read(String k) async => data[k];
  @override
  Future<void> delete(String k) async => data.remove(k);
}

class _MemRepo implements HostRepository {
  final Map<String, Host> hosts = {};
  @override
  Future<void> upsertHost(Host host) async => hosts[host.id] = host;
  @override
  Future<void> deleteHost(String id) async => hosts.remove(id);
  @override
  Future<Host?> getHost(String id) async => hosts[id];
  @override
  Future<List<Host>> getHosts() async => hosts.values.toList();
  @override
  Stream<List<Host>> watchHosts() => Stream.value(hosts.values.toList());
}

void main() {
  late _MemStore store;
  late _MemRepo repo;
  late HostService service;

  setUp(() {
    store = _MemStore();
    repo = _MemRepo();
    service = HostService(repo, SecureVault(store));
  });

  test('saveHost persists metadata to repo and password to vault', () async {
    final host = await service.saveHost(
      label: 'web',
      hostname: 'example.com',
      port: 22,
      username: 'root',
      authMethod: AuthMethod.password,
      password: 's3cret',
    );

    expect(repo.hosts[host.id], isNotNull);
    // Password lives in the vault, never in the host metadata.
    expect(store.data.values, contains('s3cret'));
    expect(host.credentialId, isNotNull);
  });

  test('buildRequest reconstructs the secret from the vault', () async {
    final host = await service.saveHost(
      label: 'web',
      hostname: 'example.com',
      port: 2222,
      username: 'deploy',
      authMethod: AuthMethod.password,
      password: 'pw123',
    );

    final req = await service.buildRequest(host);
    expect(req.authKind, SshAuthKind.password);
    expect(req.password, 'pw123');
    expect(req.port, 2222);
    expect(req.username, 'deploy');
  });

  test('key auth round-trips private key and passphrase', () async {
    final host = await service.saveHost(
      label: 'key host',
      hostname: '10.0.0.1',
      port: 22,
      username: 'admin',
      authMethod: AuthMethod.sshKey,
      privateKeyPem: '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n',
      passphrase: 'phrase',
    );

    final req = await service.buildRequest(host);
    expect(req.authKind, SshAuthKind.key);
    expect(req.privateKeyPem, contains('OPENSSH PRIVATE KEY'));
    expect(req.passphrase, 'phrase');
  });

  test('editing with a blank secret keeps the existing one', () async {
    final host = await service.saveHost(
      label: 'web',
      hostname: 'example.com',
      port: 22,
      username: 'root',
      authMethod: AuthMethod.password,
      password: 'keepme',
    );

    final edited = await service.saveHost(
      existing: host,
      label: 'web renamed',
      hostname: 'example.com',
      port: 22,
      username: 'root',
      authMethod: AuthMethod.password,
      password: '', // blank => keep
    );

    expect(edited.id, host.id);
    expect(edited.credentialId, host.credentialId);
    final req = await service.buildRequest(edited);
    expect(req.password, 'keepme');
  });

  test('deleteHost removes metadata and secret', () async {
    final host = await service.saveHost(
      label: 'web',
      hostname: 'example.com',
      port: 22,
      username: 'root',
      authMethod: AuthMethod.password,
      password: 'gone',
    );

    await service.deleteHost(host);
    expect(repo.hosts, isEmpty);
    expect(store.data, isEmpty);
  });
}
