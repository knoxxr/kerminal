/// One host entry recovered from an OpenSSH `config` file.
class SshConfigHost {
  const SshConfigHost({
    required this.alias,
    required this.hostname,
    required this.port,
    required this.username,
    this.identityFile,
    this.proxyJump,
  });

  /// The name after `Host` — what the user types as `ssh <alias>`.
  final String alias;

  /// `HostName`, falling back to [alias] when the file omits it (which is the
  /// common shorthand for `Host example.com`).
  final String hostname;
  final int port;

  /// `User`, empty when unset — the app then falls back to the OS user.
  final String username;

  /// `IdentityFile` path, kept only to tell the user which key to supply. The
  /// key itself is never read from disk here.
  final String? identityFile;

  /// `ProxyJump` target, kept for display: Kerminal cannot use it yet, so an
  /// entry that needs it must be flagged rather than silently imported as a
  /// direct connection that will not work.
  final String? proxyJump;

  bool get needsJumpHost => proxyJump != null && proxyJump!.isNotEmpty;
}

/// Parses an OpenSSH client config into importable hosts.
///
/// Deliberately partial: it understands the directives that map onto a Kerminal
/// host and ignores the rest, rather than pretending to implement ssh_config.
/// Notably it does **not** expand `Include`, and skips patterns (`Host *`,
/// `web-*`) because those are defaults for other entries, not connectable
/// servers.
class SshConfigParser {
  const SshConfigParser();

  /// Directives are case-insensitive in OpenSSH, and `key value` may be
  /// separated by whitespace or `=`.
  static final _separator = RegExp(r'[\s=]+');

  List<SshConfigHost> parse(String content) {
    final hosts = <SshConfigHost>[];

    // Values that apply to the block currently being read.
    List<String>? aliases;
    String? hostname;
    String? port;
    String? user;
    String? identityFile;
    String? proxyJump;

    void flush() {
      if (aliases == null) return;
      for (final alias in aliases!) {
        // `Host *` and other patterns set defaults for real entries; importing
        // them would create hosts nobody can connect to.
        if (alias.contains('*') || alias.contains('?') || alias == '!') continue;
        final resolved = (hostname ?? alias).trim();
        if (resolved.isEmpty) continue;
        hosts.add(
          SshConfigHost(
            alias: alias,
            hostname: resolved,
            port: int.tryParse(port ?? '') ?? 22,
            username: (user ?? '').trim(),
            identityFile: identityFile?.trim(),
            proxyJump: proxyJump?.trim(),
          ),
        );
      }
      aliases = null;
      hostname = port = user = identityFile = proxyJump = null;
    }

    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split(_separator);
      if (parts.length < 2) continue;
      final key = parts.first.toLowerCase();
      final value = parts.skip(1).join(' ').trim();
      if (value.isEmpty) continue;

      switch (key) {
        case 'host':
          // A new block ends the previous one.
          flush();
          aliases = parts.skip(1).where((a) => a.isNotEmpty).toList();
        case 'match':
          // Conditional blocks depend on runtime state we cannot evaluate;
          // ending the current block stops their directives leaking into it.
          flush();
        case 'hostname':
          hostname = _unquote(value);
        case 'port':
          port = value;
        case 'user':
          user = _unquote(value);
        case 'identityfile':
          identityFile = _unquote(value);
        case 'proxyjump':
          proxyJump = _unquote(value);
      }
    }
    flush();
    return hosts;
  }

  String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
