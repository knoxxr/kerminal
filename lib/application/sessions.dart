import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/ssh/ssh_service.dart';
import '../domain/entities/ssh_connection_request.dart';
import 'ssh_terminal_controller.dart';

/// One open terminal tab: its connection request and live controller.
class TerminalSession {
  TerminalSession({
    required this.id,
    required this.request,
    required this.controller,
    this.verifyHostKey,
  });

  final String id;
  final SshConnectionRequest request;
  final SshTerminalController controller;
  final HostKeyVerifier? verifyHostKey;
}

/// Owns the set of open terminal sessions (tabs) for the whole app.
class SessionsController extends Notifier<List<TerminalSession>> {
  final _uuid = const Uuid();

  // Live controllers, tracked in a plain field so the dispose lifecycle can
  // clean them up without reading `state`/`ref` (which Riverpod forbids there).
  final _live = <SshTerminalController>{};

  @override
  List<TerminalSession> build() {
    ref.onDispose(() {
      for (final c in _live) {
        c.dispose();
      }
      _live.clear();
    });
    return const [];
  }

  /// Opens a new session and starts connecting. Returns its id.
  String open(
    SshConnectionRequest request, {
    HostKeyVerifier? verifyHostKey,
  }) {
    final id = _uuid.v4();
    final controller = SshTerminalController();
    _live.add(controller);
    state = [
      ...state,
      TerminalSession(
        id: id,
        request: request,
        controller: controller,
        verifyHostKey: verifyHostKey,
      ),
    ];
    controller.connect(request, verifyHostKey: verifyHostKey);
    return id;
  }

  void close(String id) {
    final remaining = <TerminalSession>[];
    for (final s in state) {
      if (s.id == id) {
        _live.remove(s.controller);
        s.controller.dispose();
      } else {
        remaining.add(s);
      }
    }
    state = remaining;
  }

  /// Recreates the controller for a session and reconnects (same request).
  void reconnect(String id) {
    state = [
      for (final s in state)
        if (s.id == id) _reconnected(s) else s,
    ];
  }

  TerminalSession _reconnected(TerminalSession old) {
    _live.remove(old.controller);
    old.controller.dispose();
    final controller = SshTerminalController();
    _live.add(controller);
    controller.connect(old.request, verifyHostKey: old.verifyHostKey);
    return TerminalSession(
      id: old.id,
      request: old.request,
      controller: controller,
      verifyHostKey: old.verifyHostKey,
    );
  }
}

final sessionsProvider =
    NotifierProvider<SessionsController, List<TerminalSession>>(
  SessionsController.new,
);
