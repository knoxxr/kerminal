import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/data/ssh/remote_path.dart';

void main() {
  group('normalize', () {
    test('collapses separators and drops a trailing slash', () {
      expect(RemotePath.normalize('/var//log/'), '/var/log');
      expect(RemotePath.normalize('/'), '/');
      expect(RemotePath.normalize(''), '/');
    });

    test('resolves . and ..', () {
      expect(RemotePath.normalize('/var/log/../run'), '/var/run');
      expect(RemotePath.normalize('/var/./log'), '/var/log');
    });

    test('clamps .. at the root instead of escaping it', () {
      // A remote path cannot be relative to anything above '/', and letting it
      // escape would send the server nonsense like /../../etc.
      expect(RemotePath.normalize('/../..'), '/');
      expect(RemotePath.normalize('/var/../../etc'), '/etc');
    });

    test('keeps relative paths relative', () {
      expect(RemotePath.normalize('a/b'), 'a/b');
      expect(RemotePath.normalize('./a'), 'a');
      expect(RemotePath.normalize('../a'), '../a');
    });
  });

  group('join', () {
    test('appends a name without doubling the separator', () {
      expect(RemotePath.join('/var', 'log'), '/var/log');
      expect(RemotePath.join('/var/', 'log'), '/var/log');
      expect(RemotePath.join('/', 'etc'), '/etc');
    });

    test('an absolute name replaces the directory', () {
      expect(RemotePath.join('/var/log', '/etc/passwd'), '/etc/passwd');
    });

    test('an empty directory is treated as the root', () {
      expect(RemotePath.join('', 'etc'), '/etc');
    });
  });

  group('parent', () {
    test('walks up one level', () {
      expect(RemotePath.parent('/var/log/syslog'), '/var/log');
      expect(RemotePath.parent('/var'), '/');
    });

    test('the root is its own parent, so "up" never breaks', () {
      expect(RemotePath.parent('/'), '/');
      expect(RemotePath.parent(''), '/');
    });

    test('ignores a trailing slash', () {
      expect(RemotePath.parent('/var/log/'), '/var');
    });
  });

  group('basename', () {
    test('returns the last segment', () {
      expect(RemotePath.basename('/var/log/syslog'), 'syslog');
      expect(RemotePath.basename('/var/log/'), 'log');
    });

    test('the root has itself as a name', () {
      expect(RemotePath.basename('/'), '/');
    });
  });

  group('breadcrumbs', () {
    test('starts at the root and adds each level', () {
      final crumbs = RemotePath.breadcrumbs('/var/log');
      expect(crumbs.map((c) => c.name), ['/', 'var', 'log']);
      expect(crumbs.map((c) => c.path), ['/', '/var', '/var/log']);
    });

    test('the root alone is a single crumb', () {
      final crumbs = RemotePath.breadcrumbs('/');
      expect(crumbs, hasLength(1));
      expect(crumbs.single.path, '/');
    });

    test('each crumb path is usable for navigation', () {
      // Tapping a crumb must land exactly on that directory.
      for (final c in RemotePath.breadcrumbs('/home/user/projects')) {
        expect(RemotePath.normalize(c.path), c.path);
      }
    });
  });
}
