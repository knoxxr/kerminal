import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';

import '../../application/ssh_terminal_controller.dart';
import '../../domain/entities/ssh_connection_request.dart';

/// Live terminal for a single SSH connection. Owns an [SshTerminalController]
/// for the screen's lifetime and reflects its connection status in the UI.
class TerminalPage extends StatefulWidget {
  const TerminalPage({required this.request, super.key});

  final SshConnectionRequest request;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late final SshTerminalController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SshTerminalController();
    _controller.connect(widget.request);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('hosts'),
        ),
        title: Text(widget.request.displayName),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _StatusChip(status: _controller.status),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            children: [
              if (_controller.status == SshConnectionStatus.connecting)
                const LinearProgressIndicator(minHeight: 2),
              if (_controller.status == SshConnectionStatus.failed)
                _FailureBanner(
                  message: _controller.errorMessage ?? 'Connection failed',
                  onRetry: () => context.pushReplacementNamed(
                    'connect',
                    extra: widget.request,
                  ),
                ),
              Expanded(
                child: TerminalView(
                  _controller.terminal,
                  autofocus: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SshConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SshConnectionStatus.idle => ('Idle', Colors.grey),
      SshConnectionStatus.connecting => ('Connecting', Colors.orange),
      SshConnectionStatus.connected => ('Connected', Colors.green),
      SshConnectionStatus.failed => ('Failed', Colors.red),
      SshConnectionStatus.closed => ('Closed', Colors.grey),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: CircleAvatar(backgroundColor: color, radius: 5),
      label: Text(label),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      leading: const Icon(Icons.error_outline),
      content: Text(message),
      actions: [
        TextButton(onPressed: onRetry, child: const Text('Edit & retry')),
      ],
    );
  }
}
