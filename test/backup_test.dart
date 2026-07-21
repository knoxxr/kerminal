import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/application/host_service.dart';
import 'package:kerminal/data/crypto/backup_crypto.dart';
import 'package:kerminal/data/vault/secure_vault.dart';
import 'package:kerminal/domain/entities/host.dart';
import 'package:kerminal/domain/repositories/host_repository.dart';
import 'package:pointycastle/export.dart' show InvalidCipherTextException;

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
  Future<void> upsertHost(Host h) async => hosts[h.id] = h;
  @override
  Future<void> deleteHost(String id) async => hosts.remove(id);
  @override
  Future<Host?> getHost(String id) async => hosts[id];
  @override
  Future<List<Host>> getHosts() async => hosts.values.toList();
  @override
  Stream<List<Host>> watchHosts() => Stream.value(hosts.values.toList());
}

(_MemRepo, HostService) _make() {
  final repo = _MemRepo();
  return (repo, HostService(repo, SecureVault(_MemStore())));
}

void main() {
  group('BackupCrypto', () {
    test('round-trips plaintext with the right passphrase', () {
      final env = BackupCrypto.encrypt('hello secret', 'pw123');
      expect(env, contains('kerminal-backup'));
      expect(env, isNot(contains('hello secret'))); // ciphertext, not plaintext
      expect(BackupCrypto.decrypt(env, 'pw123'), 'hello secret');
    });

    test('wrong passphrase fails authentication', () {
      final env = BackupCrypto.encrypt('data', 'correct');
      expect(() => BackupCrypto.decrypt(env, 'wrong'),
          throwsA(isA<InvalidCipherTextException>()));
    });
  });

  group('HostService backup', () {
    test('export then import restores hosts and secrets', () async {
      final (_, source) = _make();
      await source.saveHost(
        label: 'web',
        hostname: 'example.com',
        port: 2222,
        username: 'deploy',
        groupName: 'Prod',
        authMethod: AuthMethod.password,
        password: 'p@ss',
      );
      await source.saveHost(
        label: 'key host',
        hostname: '10.0.0.9',
        port: 22,
        username: 'admin',
        authMethod: AuthMethod.sshKey,
        privateKeyPem: '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n',
        passphrase: 'kp',
      );

      final envelope = await source.exportEncrypted('backup-pw');

      // Import into a completely separate service (fresh repo + vault).
      final (targetRepo, target) = _make();
      final count = await target.importEncrypted(envelope, 'backup-pw');
      expect(count, 2);

      final hosts = await targetRepo.getHosts()
        ..sort((a, b) => a.label.compareTo(b.label));
      expect(hosts, hasLength(2));

      final web = hosts.firstWhere((h) => h.label == 'web');
      expect(web.hostname, 'example.com');
      expect(web.port, 2222);
      expect(web.groupName, 'Prod');
      final webReq = await target.buildRequest(web);
      expect(webReq.password, 'p@ss'); // secret survived the encrypted bundle

      final keyHost = hosts.firstWhere((h) => h.label == 'key host');
      final keyReq = await target.buildRequest(keyHost);
      expect(keyReq.privateKeyPem, contains('OPENSSH PRIVATE KEY'));
      expect(keyReq.passphrase, 'kp');
    });

    test('import with wrong passphrase throws BackupDecryptException', () async {
      final (_, source) = _make();
      await source.saveHost(
        label: 'x',
        hostname: 'h',
        port: 22,
        username: 'u',
        authMethod: AuthMethod.password,
        password: 'pw',
      );
      final envelope = await source.exportEncrypted('right');

      final (_, target) = _make();
      expect(
        () => target.importEncrypted(envelope, 'wrong'),
        throwsA(isA<BackupDecryptException>()),
      );
    });
  });
}
