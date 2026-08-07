import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/data/ssh/ssh_config_parser.dart';

void main() {
  const parser = SshConfigParser();

  test('reads a plain entry', () {
    final hosts = parser.parse('''
Host prod
  HostName example.com
  Port 2222
  User deploy
''');
    expect(hosts, hasLength(1));
    expect(hosts.single.alias, 'prod');
    expect(hosts.single.hostname, 'example.com');
    expect(hosts.single.port, 2222);
    expect(hosts.single.username, 'deploy');
  });

  test('falls back to the alias when HostName is omitted', () {
    // `Host example.com` with no HostName is the common shorthand.
    final hosts = parser.parse('Host example.com\n  User root\n');
    expect(hosts.single.hostname, 'example.com');
    expect(hosts.single.port, 22, reason: 'default SSH port');
  });

  test('skips patterns — they configure other entries, not real servers', () {
    final hosts = parser.parse('''
Host *
  User default-user

Host bastion?
  HostName b.example.com

Host real
  HostName r.example.com
''');
    expect(hosts.map((h) => h.alias), ['real']);
  });

  test('one Host line can declare several aliases', () {
    final hosts = parser.parse('Host a b\n  HostName shared.example.com\n');
    expect(hosts.map((h) => h.alias), ['a', 'b']);
    expect(hosts.every((h) => h.hostname == 'shared.example.com'), isTrue);
  });

  test('directives are case-insensitive and accept "=" separators', () {
    final hosts = parser.parse('''
HOST prod
  hostname=example.com
  PORT = 2200
  user=deploy
''');
    expect(hosts.single.hostname, 'example.com');
    expect(hosts.single.port, 2200);
    expect(hosts.single.username, 'deploy');
  });

  test('comments and blank lines are ignored', () {
    final hosts = parser.parse('''
# a comment
Host prod

  # indented comment
  HostName example.com
''');
    expect(hosts.single.hostname, 'example.com');
  });

  test('values do not leak from one block into the next', () {
    // The bug this guards: `web` inheriting db's port or user.
    final hosts = parser.parse('''
Host db
  HostName db.example.com
  Port 5555
  User dba

Host web
  HostName web.example.com
''');
    final web = hosts.firstWhere((h) => h.alias == 'web');
    expect(web.port, 22);
    expect(web.username, isEmpty);
  });

  test('a Match block ends the previous Host block', () {
    // Match conditions cannot be evaluated here; its directives must not be
    // attributed to the Host above it.
    final hosts = parser.parse('''
Host prod
  HostName example.com

Match host nope
  User should-not-apply
''');
    expect(hosts, hasLength(1));
    expect(hosts.single.username, isEmpty);
  });

  test('ProxyJump is reported so the entry can be flagged', () {
    // Kerminal cannot chain through a bastion yet, so importing it silently
    // would create a host that never connects.
    final hosts = parser.parse('''
Host behind
  HostName internal.example.com
  ProxyJump bastion.example.com
''');
    expect(hosts.single.needsJumpHost, isTrue);
    expect(hosts.single.proxyJump, 'bastion.example.com');
  });

  test('IdentityFile is captured, quotes stripped', () {
    final hosts = parser.parse('''
Host prod
  HostName example.com
  IdentityFile "~/.ssh/id_ed25519"
''');
    expect(hosts.single.identityFile, '~/.ssh/id_ed25519');
    expect(hosts.single.needsJumpHost, isFalse);
  });

  test('a bad Port falls back to 22 rather than throwing', () {
    final hosts = parser.parse('Host prod\n  HostName e.com\n  Port abc\n');
    expect(hosts.single.port, 22);
  });

  test('an empty or junk file yields no hosts', () {
    expect(parser.parse(''), isEmpty);
    expect(parser.parse('\n\n# only comments\n'), isEmpty);
    expect(parser.parse('HostName orphan.example.com\n'), isEmpty,
        reason: 'directives outside a Host block belong to nothing');
  });
}
