import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kominal/data/ssh/key_generator.dart';

void main() {
  const generator = SshKeyGenerator();

  test('generates a parseable OpenSSH Ed25519 private key', () {
    final key = generator.generateEd25519(comment: 'test@kominal');

    expect(key.privateKeyPem, contains('BEGIN OPENSSH PRIVATE KEY'));
    expect(key.publicKeyLine, startsWith('ssh-ed25519 '));
    expect(key.publicKeyLine, endsWith('test@kominal'));

    // dartssh2 must be able to parse what we produced (this is what auth uses).
    final parsed = SSHKeyPair.fromPem(key.privateKeyPem);
    expect(parsed, hasLength(1));
    expect(parsed.first.type, 'ssh-ed25519');
  });

  test('each generated key is unique', () {
    final a = generator.generateEd25519();
    final b = generator.generateEd25519();
    expect(a.publicKeyLine, isNot(b.publicKeyLine));
  });
}
