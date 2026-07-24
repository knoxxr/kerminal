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
        title: const Text('Hosts'),
        actions: [
          IconButton(
            tooltip: 'Quick Connect',
            icon: const Icon(Icons.bolt),
            onPressed: () => context.pushNamed('connect'),
          ),
          IconButton(
            tooltip: 'Recently deleted',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => showTrashSheet(context),
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
        ],
      ),
      body: const HostListView(navigateAfterConnect: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('newHost'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
