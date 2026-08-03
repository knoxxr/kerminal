import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform/session_keep_alive.dart';
import 'sessions.dart';

/// Keeps open SSH sessions usable across app switches.
///
/// On Android the sessions are meant to *survive* the app switch: a foreground
/// service ([SessionKeepAlive]) holds the process so the sockets stay open. iOS
/// suspends the process regardless, so there a tab comes back dead.
///
/// Either way, on [AppLifecycleState.resumed] every session is probed and
/// silently redialled when its link turns out to be gone — the tabs, their order
/// and their scrollback all stay put. This is the safety net for the cases the
/// keep-alive can't cover (iOS, or Android killing the process anyway).
///
/// Sessions themselves live in the global [sessionsProvider], so leaving the
/// terminal route never closes them; only this resume check is needed.
class SessionLifecycleObserver extends ConsumerStatefulWidget {
  const SessionLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionLifecycleObserver> createState() =>
      _SessionLifecycleObserverState();
}

class _SessionLifecycleObserverState
    extends ConsumerState<SessionLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A keep-alive service can outlive the isolate that started it; this run has
    // no sessions yet, so clear any orphaned one.
    SessionKeepAlive.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionsProvider.notifier).resumeAll();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
