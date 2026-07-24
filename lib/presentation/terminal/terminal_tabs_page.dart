import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/known_hosts.dart';
import '../../application/sessions.dart';
import '../../application/ssh_terminal_controller.dart';
import '../hosts/host_list_view.dart';
import 'host_key_prompt.dart';
import 'session_palette.dart';
import 'terminal_session_view.dart';

/// Terminal workspace: the host list as a collapsible left sidebar, connection
/// tabs at the top-right, and the active terminal filling the rest. Sessions
/// are kept alive in an [IndexedStack] so switching tabs preserves scrollback.
class TerminalTabsPage extends ConsumerStatefulWidget {
  const TerminalTabsPage({super.key});

  @override
  ConsumerState<TerminalTabsPage> createState() => _TerminalTabsPageState();
}

class _TerminalTabsPageState extends ConsumerState<TerminalTabsPage> {
  int _index = 0;
  bool _sidebarVisible = true;

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
          tooltip: _sidebarVisible ? '호스트 목록 숨기기' : '호스트 목록 보기',
          icon: Icon(_sidebarVisible ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
        ),
        titleSpacing: 0,
        // Connection tabs, top-right (scrolls when they overflow).
        title: SizedBox(
          height: 46,
          child: Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < sessions.length; i++)
                    _Tab(
                      session: sessions[i],
                      accent: sessionAccent(i),
                      selected: i == index,
                      onTap: () => setState(() => _index = i),
                      onClose: () => _close(sessions[i].id, sessions.length),
                      onDuplicate: () => _duplicate(sessions[i]),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New connection',
            icon: const Icon(Icons.add),
            onPressed: () => context.pushNamed('connect'),
          ),
        ],
      ),
      body: Row(
        children: [
          if (_sidebarVisible) ...[
            SizedBox(
              width: 300,
              child: HostListView(
                navigateAfterConnect: false,
                onConnected: () => setState(
                  () => _index = ref.read(sessionsProvider).length - 1,
                ),
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < sessions.length; i++)
                  TerminalSessionView(
                    key: ValueKey(sessions[i].id),
                    session: sessions[i],
                    accent: sessionAccent(i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens another session to the same host as [s] (right-click "duplicate").
  void _duplicate(TerminalSession s) {
    final verifier = buildHostKeyVerifier(ref.read(knownHostsProvider));
    ref.read(sessionsProvider.notifier).open(s.request, verifyHostKey: verifier);
    setState(() => _index = ref.read(sessionsProvider).length - 1);
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

class _Tab extends StatelessWidget {
  const _Tab({
    required this.session,
    required this.accent,
    required this.selected,
    required this.onTap,
    required this.onClose,
    required this.onDuplicate,
  });

  final TerminalSession session;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onDuplicate;

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_all_outlined),
            title: Text('Duplicate'),
          ),
        ),
        PopupMenuItem(
          value: 'close',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.close),
            title: Text('닫기'),
          ),
        ),
      ],
    );
    if (selected == 'duplicate') {
      onDuplicate();
    } else if (selected == 'close') {
      onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Material(
        // Selected tab is strongly tinted with its accent so the active target
        // is obvious; the same accent marks the terminal header/border.
        color: selected
            ? accent.withValues(alpha: 0.30)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        // Right-click opens a context menu (Duplicate / Close).
        child: GestureDetector(
          onSecondaryTapUp: (details) =>
              _showContextMenu(context, details.globalPosition),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: session.controller,
                    builder: (context, _) =>
                        _StatusDot(status: session.controller.status),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    session.request.displayName,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: '닫기',
                    onPressed: onClose,
                  ),
                ],
              ),
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
