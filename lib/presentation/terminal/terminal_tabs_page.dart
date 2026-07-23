import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/sessions.dart';
import '../../application/ssh_terminal_controller.dart';
import 'terminal_session_view.dart';

/// Multi-session terminal shell: a tab per open connection, kept alive in an
/// [IndexedStack] so switching tabs preserves each session's scrollback.
class TerminalTabsPage extends ConsumerStatefulWidget {
  const TerminalTabsPage({super.key});

  @override
  ConsumerState<TerminalTabsPage> createState() => _TerminalTabsPageState();
}

class _TerminalTabsPageState extends ConsumerState<TerminalTabsPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);

    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terminal')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No open sessions.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.goNamed('hosts'),
                child: const Text('Back to hosts'),
              ),
            ],
          ),
        ),
      );
    }

    final index = _index.clamp(0, sessions.length - 1);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Hosts',
          icon: const Icon(Icons.list),
          onPressed: () => context.goNamed('hosts'),
        ),
        title: Text(sessions[index].request.displayName),
        actions: [
          IconButton(
            tooltip: 'New connection',
            icon: const Icon(Icons.add),
            onPressed: () => context.pushNamed('connect'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              // First slot is a Home tab that returns to the host list.
              itemCount: sessions.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _HomeTab(onTap: () => context.goNamed('hosts'));
                }
                final s = i - 1;
                return _Tab(
                  session: sessions[s],
                  selected: s == index,
                  onTap: () => setState(() => _index = s),
                  onClose: () => _close(sessions[s].id, sessions.length),
                );
              },
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: index,
        children: [
          for (final s in sessions)
            TerminalSessionView(key: ValueKey(s.id), session: s),
        ],
      ),
    );
  }

  void _close(String id, int count) {
    ref.read(sessionsProvider.notifier).close(id);
    if (count <= 1) {
      context.goNamed('hosts');
    } else {
      setState(() => _index = _index.clamp(0, count - 2));
    }
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Home',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final TerminalSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Material(
        color: selected ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: session.controller,
                  builder: (context, _) => _StatusDot(
                    status: session.controller.status,
                  ),
                ),
                const SizedBox(width: 6),
                Text(session.request.displayName),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final SshConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SshConnectionStatus.connected => Colors.green,
      SshConnectionStatus.connecting => Colors.orange,
      SshConnectionStatus.failed => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
