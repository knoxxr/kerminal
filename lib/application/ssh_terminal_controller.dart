import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../data/ssh/ssh_service.dart';
import '../domain/entities/ssh_connection_request.dart';

enum SshConnectionStatus { idle, connecting, connected, failed, closed }

/// Owns a single terminal + SSH session and exposes its lifecycle to the UI.
///
/// Presentation-scoped: created and disposed by the terminal screen rather
/// than a global provider, since a session's lifetime matches its screen.
class SshTerminalController extends ChangeNotifier {
  SshTerminalController();

  final Terminal terminal = Terminal(maxLines: 10000);

  SshConnectionStatus _status = SshConnectionStatus.idle;
  SshConnectionStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  SshSession? _session;
  bool _disposed = false;

  bool get isConnected => _status == SshConnectionStatus.connected;

  /// Opens the connection described by [request] and streams it into
  /// [terminal]. Safe to call once; re-connecting requires a fresh controller.
  Future<void> connect(
    SshConnectionRequest request, {
    HostKeyVerifier? verifyHostKey,
  }) async {
    if (_status == SshConnectionStatus.connecting || isConnected) return;

    _setStatus(SshConnectionStatus.connecting);
    terminal.write('Connecting to ${request.host}:${request.port} ...\r\n');

    try {
      final session = await SshSession.connect(
        terminal: terminal,
        request: request,
        verifyHostKey: verifyHostKey,
      );
      if (_disposed) {
        session.close();
        return;
      }
      _session = session;
      _setStatus(SshConnectionStatus.connected);

      // React to remote-initiated teardown.
      session.done.whenComplete(() {
        if (_disposed) return;
        _setStatus(SshConnectionStatus.closed);
        terminal.write('\r\n[Connection closed]\r\n');
      });
    } catch (e) {
      _errorMessage = _describe(e);
      terminal.write('\r\n[Connection failed] $_errorMessage\r\n');
      _setStatus(SshConnectionStatus.failed);
    }
  }

  String _describe(Object e) {
    final text = e.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }

  void _setStatus(SshConnectionStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.close();
    super.dispose();
  }
}
