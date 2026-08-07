import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/application/host_service.dart';
import 'package:kerminal/data/remote/identity_repository.dart';
import 'package:kerminal/data/vault/secure_vault.dart';
import 'package:kerminal/domain/entities/host.dart';
import 'package:kerminal/domain/repositories/host_repository.dart';

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
  group('IdentityRepository.normalizeEmail', () {
    test('lowercases and trims, so lookup can ever match', () {
      // Sharing matches on exact equality: a profile stored as
      // Foo@Example.com was unreachable for anyone typing it in lower case.
      expect(
        IdentityRepository.normalizeEmail('  Foo@Example.COM '),
        'foo@example.com',
      );
    });

    test('is idempotent', () {
      const email = 'user@example.com';
      expect(IdentityRepository.normalizeEmail(email), email);
      expect(
        IdentityRepository.normalizeEmail(
          IdentityRepository.normalizeEmail('A@B.com'),
        ),
        'a@b.com',
      );
    });
  });

  group('HostService.saveHost secret hygiene', () {
    late _MemStore store;
    late _MemRepo repo;
    late HostService service;

    setUp(() {
      store = _MemStore();
      repo = _MemRepo();
      service = HostService(repo, SecureVault(store));
    });

    Future<Host> savePasswordHost() => service.saveHost(
          label: 'web',
          hostname: 'example.com',
          port: 22,
          username: 'root',
          authMethod: AuthMethod.password,
          password: 'secret',
        );

    test('switching password → key drops the stored password', () async {
      final host = await savePasswordHost();
      expect(store.data.keys.where((k) => k.endsWith('/password')), hasLength(1));

      // The user picks SSH key but pastes no key yet (a realistic edit).
      await service.saveHost(
        existing: host,
        label: 'web',
        hostname: 'example.com',
        port: 22,
        username: 'root',
        authMethod: AuthMethod.sshKey,
      );

      // Previously the password stayed in the vault forever while the host
      // tried to connect with an empty key.
      expect(
        store.data.keys.where((k) => k.endsWith('/password')),
        isEmpty,
        reason: 'stale password must not survive a method change',
      );
    });

    test('switching with no new secret does not crash on the null secret',
        () async {
      final host = await savePasswordHost();
      // Guards the null-assertion path: clearing and writing are separate steps.
      await expectLater(
        service.saveHost(
          existing: host,
          label: 'web',
          hostname: 'example.com',
          port: 22,
          username: 'root',
          authMethod: AuthMethod.sshKey,
        ),
        completes,
      );
    });

    test('editing without changing the method keeps the secret', () async {
      final host = await savePasswordHost();
      await service.saveHost(
        existing: host,
        label: 'renamed',
        hostname: 'example.com',
        port: 22,
        username: 'root',
        authMethod: AuthMethod.password,
      );
      // Renaming must not force the user to re-enter their password.
      final request = await service.buildRequest(repo.hosts[host.id]!);
      expect(request.password, 'secret');
    });

    test('switching key → password drops the stored key and passphrase',
        () async {
      final host = await service.saveHost(
        label: 'web',
        hostname: 'example.com',
        port: 22,
        username: 'root',
        authMethod: AuthMethod.sshKey,
        privateKeyPem: 'KEY',
        passphrase: 'pass',
      );
      expect(store.data.keys.where((k) => k.endsWith('/privateKey')),
          hasLength(1));

      await service.saveHost(
        existing: host,
        label: 'web',
        hostname: 'example.com',
        port: 22,
        username: 'root',
        authMethod: AuthMethod.password,
        password: 'pw',
      );

      expect(store.data.keys.where((k) => k.endsWith('/privateKey')), isEmpty);
      expect(store.data.keys.where((k) => k.endsWith('/passphrase')), isEmpty);
    });
  });
}
