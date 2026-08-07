import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../data/ssh/ssh_service.dart';
import '../domain/entities/ssh_connection_request.dart';

enum SshConnectionStatus { idle, connecting, connected, failed, closed }

/// Owns a single terminal + SSH session and exposes its lifecycle to the UI.
///
/// Presentation-scoped: created and disposed by the terminal screen rather
/// than a global provider, since a session's lifetime matches its screen.
///
/// The connection request is remembered after the first [connect], so the
/// controller can redial itself ([reconnect], [ensureAlive]) while reusing the
/// same [terminal] — a reconnect therefore keeps the scrollback.
class SshTerminalController extends ChangeNotifier {
  SshTerminalController();

  final Terminal terminal = Terminal(maxLines: 10000);

  SshConnectionStatus _status = SshConnectionStatus.idle;
  SshConnectionStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  SshSession? _session;
  bool _disposed = false;

  SshConnectionRequest? _request;
  HostKeyVerifier? _verifyHostKey;
  SshUserInfoResponder? _respondToPrompts;

  /// Bumped for every dial. Callbacks (notably `done`) captured by a superseded
  /// link compare against it so a stale teardown can't clobber the live one.
  int _generation = 0;
  Future<void>? _inFlight;

  /// Whether this session ever reached [SshConnectionStatus.connected].
  /// Only such sessions are redialled automatically: a link that never came up
  /// usually failed on credentials or DNS, which retrying won't fix.
  bool _everConnected = false;

  bool _probing = false;

  bool get isConnected => _status == SshConnectionStatus.connected;

  /// Opens the connection described by [request] and streams it into
  /// [terminal].
  Future<void> connect(
    SshConnectionRequest request, {
    HostKeyVerifier? verifyHostKey,
    SshUserInfoResponder? respondToPrompts,
  }) {
    _request = request;
    _verifyHostKey = verifyHostKey;
    _respondToPrompts = respondToPrompts;
    if (_status == SshConnectionStatus.connecting || isConnected) {
      return _inFlight ?? Future<void>.value();
    }
    return _dial();
  }

  /// Drops the current link (if any) and dials the same host again, reusing
  /// this controller's [terminal] so the scrollback survives.
  Future<void> reconnect() {
    if (_disposed || _request == null) return Future<void>.value();
    if (_status == SshConnectionStatus.connecting) {
      return _inFlight ?? Future<void>.value();
    }
    _teardown();
    return _dial();
  }

  /// Re-establishes the session if it died while the app was in the background.
  ///
  /// Mobile OSes suspend the process on an app switch; iOS in particular tears
  /// the TCP socket down, so a tab that looked connected comes back dead. This
  /// probes the link on resume and silently redials when it is gone, instead of
  /// leaving the user with a dead terminal and a Reconnect button.
  Future<void> ensureAlive() async {
    if (_disposed || _request == null || _probing) return;
    if (_status == SshConnectionStatus.connecting) return;
    if (_status == SshConnectionStatus.idle) return;

    _probing = true;
    try {
      final session = _session;
      if (isConnected && session != null) {
        if (await session.isAlive()) return;
        if (_disposed || !isConnected) return;
        terminal.write('\r\n[Link dropped while in background]');
      } else if (!_everConnected) {
        // Never came up — leave the failure on screen for the user to act on.
        return;
      }
      terminal.write('\r\n[Reconnecting…]\r\n');
      await reconnect();
    } finally {
      _probing = false;
    }
  }

  Future<void> _dial() {
    if (_disposed || _request == null) return Future<void>.value();
    final future = _doDial();
    _inFlight = future;
    return future;
  }

  Future<void> _doDial() async {
    final request = _request!;
    final generation = ++_generation;

    _errorMessage = null;
    _setStatus(SshConnectionStatus.connecting);
    terminal.write('Connecting to ${request.host}:${request.port} ...\r\n');

    try {
      final session = await SshSession.connect(
        terminal: terminal,
        request: request,
        verifyHostKey: _verifyHostKey,
        respondToPrompts: _respondToPrompts,
      );
      if (_disposed || generation != _generation) {
        session.close();
        return;
      }
      _session = session;
      _everConnected = true;
      _setStatus(SshConnectionStatus.connected);

      // React to remote-initiated teardown.
      session.done.whenComplete(() {
        if (_disposed || generation != _generation) return;
        _session = null;
        _setStatus(SshConnectionStatus.closed);
        terminal.write('\r\n[Connection closed]\r\n');
      });
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _errorMessage = _describe(e);
      terminal.write('\r\n[Connection failed] $_errorMessage\r\n');
      _setStatus(SshConnectionStatus.failed);
    } finally {
      if (generation == _generation) _inFlight = null;
    }
  }

  /// Closes the live link and invalidates its callbacks.
  void _teardown() {
    _generation++;
    final session = _session;
    _session = null;
    try {
      session?.close();
    } catch (_) {
      // A transport that already died can throw on close; nothing to recover,
      // and it must not abort the reconnect that follows.
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
    _teardown();
    super.dispose();
  }
}
