import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

/// Bridges a live SSH shell session to an [xterm] [Terminal] widget model.
///
/// Phase 0 scaffold: establishes the connection + PTY plumbing so the terminal
/// stack is wired end-to-end. Auth flows and error handling are fleshed out in
/// Phase 1/2.
class SshSession {
  SshSession._(this._client, this._session);

  final SSHClient _client;
  final SSHSession _session;

  /// Connects with password auth and binds the shell to [terminal].
  static Future<SshSession> connectWithPassword({
    required Terminal terminal,
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    final socket = await SSHSocket.connect(host, port);
    final client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );

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
    terminal.onOutput = (data) {
      session.write(utf8.encode(data));
    };
    terminal.onResize = (w, h, pw, ph) {
      session.resizeTerminal(w, h, pw, ph);
    };

    return SshSession._(client, session);
  }

  void close() {
    _session.close();
    _client.close();
  }
}
