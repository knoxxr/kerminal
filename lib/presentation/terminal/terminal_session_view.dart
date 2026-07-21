import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../application/sessions.dart';
import '../../application/settings.dart';
import '../../application/ssh_terminal_controller.dart';
import 'terminal_toolbar.dart';

/// Renders a single [TerminalSession]: its live terminal, connection status,
/// reconnect banner, and the special-key toolbar.
class TerminalSessionView extends ConsumerWidget {
  const TerminalSessionView({required this.session, super.key});

  final TerminalSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(settingsProvider.select((s) => s.fontSize));
    final controller = session.controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final status = controller.status;
        final canReconnect = status == SshConnectionStatus.failed ||
            status == SshConnectionStatus.closed;
        return Column(
          children: [
            if (status == SshConnectionStatus.connecting)
              const LinearProgressIndicator(minHeight: 2),
            if (canReconnect)
              MaterialBanner(
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                leading: Icon(status == SshConnectionStatus.failed
                    ? Icons.error_outline
                    : Icons.info_outline),
                content: Text(status == SshConnectionStatus.failed
                    ? (controller.errorMessage ?? 'Connection failed')
                    : 'Session closed.'),
                actions: [
                  TextButton(
                    onPressed: () =>
                        ref.read(sessionsProvider.notifier).reconnect(session.id),
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            Expanded(
              child: TerminalView(
                controller.terminal,
                autofocus: true,
                textStyle: TerminalStyle(fontSize: fontSize),
              ),
            ),
            if (!canReconnect) TerminalToolbar(terminal: controller.terminal),
          ],
        );
      },
    );
  }
}
