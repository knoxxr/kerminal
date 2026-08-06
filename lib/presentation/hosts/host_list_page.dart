import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/update_providers.dart';
import 'history_sheets.dart';
import 'host_list_view.dart';

/// Home screen: the saved-host list (search, groups, one-click connect).
/// Connecting opens a terminal session and switches to the terminal workspace,
/// where this list is available as a collapsible left sidebar.
class HostListPage extends ConsumerWidget {
  const HostListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          IconButton(
            tooltip: 'Connect without saving',
            icon: const Icon(Icons.bolt),
            onPressed: () => context.pushNamed('connect'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: ref.watch(updateCheckProvider).maybeWhen(
                  data: (info) => (info?.updateAvailable ?? false)
                      ? const Badge(child: Icon(Icons.settings_outlined))
                      : const Icon(Icons.settings_outlined),
                  orElse: () => const Icon(Icons.settings_outlined),
                ),
            onPressed: () => context.pushNamed('settings'),
          ),
          // "Recently deleted" used to be a bare trash icon in the bar, which
          // reads as "delete something" — the opposite of what it does. In a
          // labelled menu the wording carries the meaning, and tooltips are
          // invisible on touch anyway.
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'trash') showTrashSheet(context);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'trash',
                child: Row(
                  children: [
                    Icon(Icons.restore_from_trash_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Restore a deleted server'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: const HostListView(navigateAfterConnect: true),
      // Labelled rather than a bare "+": the main action on an empty-ish list
      // should say what it adds.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('newHost'),
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
      ),
    );
  }
}
