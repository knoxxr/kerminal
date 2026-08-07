/// POSIX path helpers for remote (SFTP) paths.
///
/// `package:path` follows the *host* platform's separator, which would produce
/// `\` on Windows and silently break every remote path. Remote paths are always
/// POSIX, so they get their own small implementation.
class RemotePath {
  const RemotePath._();

  static const root = '/';

  /// Appends [name] to [dir], collapsing separators.
  static String join(String dir, String name) {
    if (name.startsWith('/')) return normalize(name);
    final base = dir.isEmpty ? root : dir;
    return normalize(base.endsWith('/') ? '$base$name' : '$base/$name');
  }

  /// The containing directory of [path], or [root] when already at the top.
  static String parent(String path) {
    final n = normalize(path);
    if (n == root) return root;
    final cut = n.lastIndexOf('/');
    if (cut <= 0) return root;
    return n.substring(0, cut);
  }

  /// The last segment of [path] (`/var/log/syslog` → `syslog`).
  static String basename(String path) {
    final n = normalize(path);
    if (n == root) return root;
    return n.substring(n.lastIndexOf('/') + 1);
  }

  /// Resolves `.`/`..`, collapses repeated slashes and drops a trailing one.
  ///
  /// `..` above the root is clamped rather than escaping it — a remote path can
  /// never be relative to anything above `/`.
  static String normalize(String path) {
    if (path.isEmpty) return root;
    final absolute = path.startsWith('/');
    final segments = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isNotEmpty && segments.last != '..') {
          segments.removeLast();
        } else if (!absolute) {
          segments.add('..');
        }
        continue;
      }
      segments.add(part);
    }
    if (absolute) return '/${segments.join('/')}';
    return segments.isEmpty ? '.' : segments.join('/');
  }

  /// Each ancestor of [path] from the root down, for a breadcrumb bar.
  /// `/var/log` → `[('/', '/'), ('var', '/var'), ('log', '/var/log')]`.
  static List<({String name, String path})> breadcrumbs(String path) {
    final n = normalize(path);
    final crumbs = <({String name, String path})>[(name: '/', path: root)];
    if (n == root) return crumbs;
    var current = '';
    for (final part in n.split('/').where((p) => p.isNotEmpty)) {
      current = '$current/$part';
      crumbs.add((name: part, path: current));
    }
    return crumbs;
  }
}
