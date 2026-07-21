/// How a connection authenticates.
enum SshAuthKind { password, key }

/// A transient request to open an SSH connection. Carries the secret material
/// in memory only — it is never persisted and never placed in a route URL.
class SshConnectionRequest {
  const SshConnectionRequest({
    required this.host,
    required this.port,
    required this.username,
    required this.authKind,
    this.password,
    this.privateKeyPem,
    this.passphrase,
    this.label,
  });

  final String host;
  final int port;
  final String username;
  final SshAuthKind authKind;

  /// Set when [authKind] is [SshAuthKind.password].
  final String? password;

  /// PEM-encoded private key, set when [authKind] is [SshAuthKind.key].
  final String? privateKeyPem;

  /// Optional passphrase protecting [privateKeyPem].
  final String? passphrase;

  /// Optional display label (falls back to `user@host`).
  final String? label;

  String get displayName => label?.isNotEmpty == true
      ? label!
      : '$username@$host:$port';
}
