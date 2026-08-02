import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/known_hosts.dart';
import '../../application/sessions.dart';
import '../../application/ssh_terminal_controller.dart';
import '../hosts/host_list_view.dart';
import 'host_key_prompt.dart';
import 'session_palette.dart';
import 'terminal_session_view.dart';

/// Below this width the workspace switches to the phone layout: the host list
/// becomes a drawer (a 300px sidebar would swallow the screen) and the tabs get
/// their own full-width row under the app bar instead of the app bar title.
const double _kCompactWidth = 700;

/// On touch platforms an immediate [Draggable] swallows the horizontal pan that
/// scrolls the tab strip, which makes every tab past the first unreachable.
/// There, reordering starts from a long-press instead.
final bool _touchReorder = !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Terminal workspace: the host list as a collapsible left sidebar (a drawer on
/// phones), connection tabs at the top, and the active terminal filling the
/// rest. Sessions are kept alive in an [IndexedStack] so switching tabs
/// preserves scrollback.
class TerminalTabsPage extends ConsumerStatefulWidget {
  const TerminalTabsPage({super.key});

  @override
  ConsumerState<TerminalTabsPage> createState() => _TerminalTabsPageState();
}

class _TerminalTabsPageState extends ConsumerState<TerminalTabsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Per-session keys on the tab widgets, used to scroll the active tab into
  /// view. Pruned in [build] as sessions close.
  final _tabKeys = <String, GlobalKey>{};

  int _index = 0;
  bool _sidebarVisible = true;

  GlobalKey _tabKey(String id) => _tabKeys.putIfAbsent(id, () => GlobalKey());

  void _select(int i) {
    setState(() => _index = i);
    _revealActiveTab();
  }

  /// Scrolls the strip so the active tab is on screen — on a phone only one or
  /// two tabs fit, so a selection change would otherwise happen off-screen.
  void _revealActiveTab() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sessions = ref.read(sessionsProvider);
      if (sessions.isEmpty) return;
      final id = sessions[_index.clamp(0, sessions.length - 1)].id;
      final tabContext = _tabKeys[id]?.currentContext;
      if (tabContext == null) return;
      Scrollable.ensureVisible(
        tabContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

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

    _tabKeys.removeWhere(
      (id, _) => !sessions.any((s) => s.id == id),
    );

    final index = _index.clamp(0, sessions.length - 1);
    final compact = MediaQuery.sizeOf(context).width < _kCompactWidth;

    return compact
        ? _compactLayout(sessions, index)
        : _wideLayout(sessions, index);
  }

  // ---------------------------------------------------------------- layouts

  /// Phone layout: host list in a drawer, tabs on their own full-width row.
  Widget _compactLayout(List<TerminalSession> sessions, int index) {
    final active = sessions[index];
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: HostListView(
            navigateAfterConnect: false,
            onConnected: () {
              _scaffoldKey.currentState?.closeDrawer();
              _select(ref.read(sessionsProvider).length - 1);
            },
          ),
        ),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        // Tapping the title opens the session picker — the reliable way to
        // switch when many tabs are open.
        title: InkWell(
          onTap: () => _showSessionPicker(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    active.request.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${index + 1}/${sessions.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '세션 목록',
            icon: Badge(
              label: Text('${sessions.length}'),
              isLabelVisible: sessions.length > 1,
              child: const Icon(Icons.tab_outlined),
            ),
            onPressed: () => _showSessionPicker(index),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed('settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(child: _tabStrip(sessions, index, compact: true)),
                // Pinned (doesn't scroll away with the strip), mirroring the
                // "+ at the right of the tabs" affordance on desktop.
                IconButton(
                  tooltip: 'Add host',
                  icon: const Icon(Icons.add, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context.pushNamed('newHost'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _terminalStack(sessions, index),
    );
  }

  /// Desktop/tablet layout: inline sidebar, tabs in the app bar title.
  Widget _wideLayout(List<TerminalSession> sessions, int index) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _sidebarVisible ? '호스트 목록 숨기기' : '호스트 목록 보기',
          icon: Icon(_sidebarVisible ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
        ),
        titleSpacing: 0,
        // Connection tabs, laid out from the left (scroll right on overflow).
        title: SizedBox(
          height: 46,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _tabStrip(sessions, index, compact: false),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add host',
            icon: const Icon(Icons.add),
            onPressed: () => context.pushNamed('newHost'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed('settings'),
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
                onConnected: () =>
                    _select(ref.read(sessionsProvider).length - 1),
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: _terminalStack(sessions, index)),
        ],
      ),
    );
  }

  Widget _terminalStack(List<TerminalSession> sessions, int index) {
    return IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < sessions.length; i++)
          TerminalSessionView(
            key: ValueKey(sessions[i].id),
            session: sessions[i],
            accent: sessionAccent(i),
            active: i == index,
          ),
      ],
    );
  }

  // ------------------------------------------------------------------- tabs

  Widget _tabStrip(
    List<TerminalSession> sessions,
    int index, {
    required bool compact,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Swipeable even when the tabs don't overflow, so the gesture is never
      // "dead" on touch.
      physics: const AlwaysScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sessions.length; i++)
            _reorderableTab(i, sessions, index, compact),
        ],
      ),
    );
  }

  /// A connection tab that can be dragged left/right to reorder (long-press
  /// first on touch). Dropping it onto another tab moves it to that position.
  Widget _reorderableTab(
    int i,
    List<TerminalSession> sessions,
    int index,
    bool compact,
  ) {
    final session = sessions[i];
    final tab = _Tab(
      session: session,
      accent: sessionAccent(i),
      selected: i == index,
      compact: compact,
      onTap: () => _select(i),
      onClose: () => _close(session.id, sessions.length),
      onDuplicate: () => _duplicate(session),
    );

    final feedback = Material(
      color: Colors.transparent,
      child: Opacity(opacity: 0.9, child: tab),
    );
    final ghost = Opacity(opacity: 0.3, child: tab);

    return DragTarget<int>(
      // The key rides on the DragTarget (mounted exactly once) so the strip can
      // scroll this tab into view; `tab` itself is reused for the drag feedback.
      key: _tabKey(session.id),
      onWillAcceptWithDetails: (details) => details.data != i,
      onAcceptWithDetails: (details) => _reorder(details.data, i),
      builder: (context, candidate, rejected) {
        // Highlight the left edge while another tab hovers as a drop hint.
        final child = AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: candidate.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
          ),
          child: tab,
        );
        return _touchReorder
            ? LongPressDraggable<int>(
                data: i,
                axis: Axis.horizontal,
                feedback: feedback,
                childWhenDragging: ghost,
                child: child,
              )
            : Draggable<int>(
                data: i,
                axis: Axis.horizontal,
                feedback: feedback,
                childWhenDragging: ghost,
                child: child,
              );
      },
    );
  }

  /// Full session list as a bottom sheet — the phone-friendly tab switcher.
  Future<void> _showSessionPicker(int index) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final sessions = ref.read(sessionsProvider);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < sessions.length; i++)
                _SessionTile(
                  session: sessions[i],
                  accent: sessionAccent(i),
                  selected: i == index,
                  onTap: () => Navigator.pop(sheetContext, i),
                  onClose: () {
                    Navigator.pop(sheetContext);
                    _close(sessions[i].id, sessions.length);
                  },
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) _select(picked);
  }

  // ----------------------------------------------------------------- actions

  /// Reorders tabs while keeping the currently selected session selected.
  void _reorder(int from, int to) {
    final sessions = ref.read(sessionsProvider);
    if (from < 0 || from >= sessions.length) return;
    final selectedId = sessions[_index.clamp(0, sessions.length - 1)].id;
    ref.read(sessionsProvider.notifier).reorder(from, to);
    final now = ref.read(sessionsProvider);
    final newIdx = now.indexWhere((s) => s.id == selectedId);
    setState(() => _index = newIdx < 0 ? 0 : newIdx);
  }

  /// Opens another session to the same host as [s] (right-click "duplicate").
  void _duplicate(TerminalSession s) {
    final verifier = buildHostKeyVerifier(ref.read(knownHostsProvider));
    ref.read(sessionsProvider.notifier).open(s.request, verifyHostKey: verifier);
    _select(ref.read(sessionsProvider).length - 1);
  }

  void _close(String id, int count) {
    ref.read(sessionsProvider.notifier).close(id);
    if (count <= 1) {
      context.goNamed('hosts');
    } else {
      _select(_index.clamp(0, count - 2));
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
    this.compact = false,
  });

  final TerminalSession session;
  final Color accent;
  final bool selected;
  final bool compact;
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
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6, horizontal: 4),
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
                  // Long host labels must not push the neighbouring tabs off
                  // the strip on a phone.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 120 : 220),
                    child: Text(
                      session.request.displayName,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
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

/// One row of the bottom-sheet session picker.
class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.accent,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final TerminalSession session;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final request = session.request;
    final target = request.username.isEmpty
        ? '${request.host}:${request.port}'
        : '${request.username}@${request.host}:${request.port}';
    return ListTile(
      selected: selected,
      leading: Container(
        width: 6,
        height: 32,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Row(
        children: [
          AnimatedBuilder(
            animation: session.controller,
            builder: (context, _) =>
                _StatusDot(status: session.controller.status),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(request.displayName, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: Text(target, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: '닫기',
        icon: const Icon(Icons.close),
        onPressed: onClose,
      ),
      onTap: onTap,
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
