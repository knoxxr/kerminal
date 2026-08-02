import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sessions.dart';

/// Keeps open SSH sessions usable across app switches.
///
/// Mobile OSes suspend the process when the user leaves the app. Android
/// usually keeps the socket (the keep-alive in `SshSession` stops carrier NAT
/// from reaping the idle flow), but iOS tears it down, so a tab that was
/// connected comes back dead. On [AppLifecycleState.resumed] every session is
/// probed and silently redialled when its link is gone — the tabs, their order
/// and their scrollback all stay put.
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
