import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../application/sessions.dart';
import '../../application/settings.dart';
import '../../application/ssh_terminal_controller.dart';
import 'terminal_toolbar.dart';

/// On desktop/web, printable characters arrive as hardware key events; xterm's
/// default text-input path only feeds them via the platform IME (mobile). So
/// desktop uses hardware-keyboard mode; mobile keeps the soft keyboard.
final bool _useHardwareKeyboard = kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Renders a single [TerminalSession]: its live terminal, connection status,
/// reconnect banner, and the special-key toolbar.
///
/// The [TerminalView] is built ONCE (outside the status [AnimatedBuilder]) and
/// keeps a dedicated [FocusNode], so status changes during connect don't
/// rebuild it or steal keyboard focus. Focus is (re)requested whenever a
/// connection becomes ready.
class TerminalSessionView extends ConsumerStatefulWidget {
  const TerminalSessionView({required this.session, super.key});

  final TerminalSession session;

  @override
  ConsumerState<TerminalSessionView> createState() =>
      _TerminalSessionViewState();
}

class _TerminalSessionViewState extends ConsumerState<TerminalSessionView> {
  final _focusNode = FocusNode(debugLabel: 'terminal');

  SshTerminalController get _controller => widget.session.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStatusChanged);
  }

  @override
  void didUpdateWidget(TerminalSessionView old) {
    super.didUpdateWidget(old);
    // Reconnect swaps in a new controller for the same session id.
    if (old.session.controller != _controller) {
      old.session.controller.removeListener(_onStatusChanged);
      _controller.addListener(_onStatusChanged);
    }
  }

  void _onStatusChanged() {
    if (_controller.status == SshConnectionStatus.connected) {
      _focusTerminal();
    }
  }

  void _focusTerminal() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onStatusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(settingsProvider.select((s) => s.fontSize));

    return Column(
      children: [
        // Only the status strip rebuilds on connection-state changes.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            switch (_controller.status) {
              case SshConnectionStatus.connecting:
                return const LinearProgressIndicator(minHeight: 2);
              case SshConnectionStatus.failed:
                return _ReconnectBanner(
                  message: _controller.errorMessage ?? 'Connection failed',
                  onReconnect: _reconnect,
                );
              case SshConnectionStatus.closed:
                return _ReconnectBanner(
                  message: 'Session closed.',
                  onReconnect: _reconnect,
                );
              case SshConnectionStatus.idle:
              case SshConnectionStatus.connected:
                return const SizedBox.shrink();
            }
          },
        ),
        Expanded(
          child: TerminalView(
            _controller.terminal,
            focusNode: _focusNode,
            autofocus: true,
            hardwareKeyboardOnly: _useHardwareKeyboard,
            textStyle: TerminalStyle(fontSize: fontSize),
          ),
        ),
        // Toolbar sends keys programmatically; exclude it from focus traversal
        // so tapping a key never steals keyboard focus from the terminal.
        ExcludeFocus(child: TerminalToolbar(terminal: _controller.terminal)),
      ],
    );
  }

  void _reconnect() =>
      ref.read(sessionsProvider.notifier).reconnect(widget.session.id);
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.message, required this.onReconnect});

  final String message;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      leading: const Icon(Icons.info_outline),
      content: Text(message),
      actions: [
        TextButton(onPressed: onReconnect, child: const Text('Reconnect')),
      ],
    );
  }
}
