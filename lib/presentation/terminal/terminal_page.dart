import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';

/// Terminal screen for a single host. Phase 1 wires this [Terminal] to a live
/// [SshSession]; for now it renders the emulator so the view is verified.
class TerminalPage extends ConsumerStatefulWidget {
  const TerminalPage({required this.hostId, super.key});

  final String hostId;

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  final terminal = Terminal(maxLines: 10000);

  @override
  void initState() {
    super.initState();
    terminal.write('kominal — terminal ready.\r\n');
    terminal.write('Host: ${widget.hostId}\r\n');
    terminal.write('SSH connection wiring lands in Phase 1.\r\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('hosts'),
        ),
        title: Text('Terminal · ${widget.hostId}'),
      ),
      body: TerminalView(terminal),
    );
  }
}
