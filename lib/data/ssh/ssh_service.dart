import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../../domain/entities/ssh_connection_request.dart';

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
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final socket = await SSHSocket.connect(
      request.host,
      request.port,
      timeout: timeout,
    );

    final client = SSHClient(
      socket,
      username: request.username,
      // Phase 1: trust on first use. Real known_hosts verification with a user
      // prompt is implemented in Phase 3.
      onVerifyHostKey: (host, key) => true,
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

  void close() {
    _session.close();
    _client.close();
  }
}
