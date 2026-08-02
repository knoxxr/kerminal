import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../../domain/entities/ssh_connection_request.dart';

/// Verifies a server's host key. Returns true to accept the connection.
/// [fingerprint] is the OpenSSH `SHA256:...` fingerprint of the host key.
typedef HostKeyVerifier = Future<bool> Function(
  String host,
  int port,
  String keyType,
  String fingerprint,
);

/// A live SSH shell bound to an [xterm] [Terminal].
///
/// [connect] establishes the transport, authenticates, opens a PTY-backed
/// shell and wires it bidirectionally to the terminal. It completes only once
/// authentication succeeds; any failure throws so the caller can surface it.
class SshSession {
  SshSession._(this._client, this._session);

  final SSHClient _client;
  final SSHSession _session;

  /// Completes when the connection is torn down (remote close, error, or
  /// [close]).
  Future<void> get done => _client.done;

  static Future<SshSession> connect({
    required Terminal terminal,
    required SshConnectionRequest request,
    HostKeyVerifier? verifyHostKey,
    Duration timeout = const Duration(seconds: 15),
    // Mobile carriers and NAT gateways drop idle TCP flows within a minute or
    // so, which is exactly what happens while the app sits in the background.
    Duration keepAliveInterval = const Duration(seconds: 20),
  }) async {
    final socket = await SSHSocket.connect(
      request.host,
      request.port,
      timeout: timeout,
    );

    final client = SSHClient(
      socket,
      username: request.username,
      keepAliveInterval: keepAliveInterval,
      // dartssh2 passes (keyType, fingerprintBytes); the fingerprint is the
      // OpenSSH "SHA256:..." string. Null verifier => trust on first use.
      onVerifyHostKey: verifyHostKey == null
          ? (type, fingerprint) => true
          : (type, fingerprint) => verifyHostKey(
                request.host,
                request.port,
                type,
                utf8.decode(fingerprint),
              ),
      identities: request.authKind == SshAuthKind.key
          ? SSHKeyPair.fromPem(
              request.privateKeyPem ?? '',
              request.passphrase?.isEmpty ?? true ? null : request.passphrase,
            )
          : null,
      onPasswordRequest: request.authKind == SshAuthKind.password
          ? () => request.password ?? ''
          : null,
    );

    try {
      await client.authenticated;
    } catch (e) {
      client.close();
      rethrow;
    }

    final session = await client.shell(
      pty: SSHPtyConfig(
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    // SSH output -> terminal.
    session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
    session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);

    // Terminal input -> SSH.
    terminal.onOutput = (data) => session.write(utf8.encode(data));
    terminal.onResize = (w, h, pw, ph) => session.resizeTerminal(w, h, pw, ph);

    return SshSession._(client, session);
  }

  bool get isClosed => _client.isClosed;

  /// Round-trips a keep-alive to find out whether the link is *really* alive.
  ///
  /// A socket killed while the app was suspended often looks open from this
  /// side until the next write times out, so [done] may not have fired yet.
  /// Returns false when the server doesn't answer within [timeout].
  Future<bool> isAlive({Duration timeout = const Duration(seconds: 5)}) async {
    if (_client.isClosed) return false;
    try {
      await _client.ping().timeout(timeout);
      return !_client.isClosed;
    } catch (_) {
      return false;
    }
  }

  void close() {
    _session.close();
    _client.close();
  }
}
