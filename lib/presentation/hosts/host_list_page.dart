import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/known_hosts.dart';
import '../../application/providers.dart';
import '../../application/sessions.dart';
import '../../application/update_providers.dart';
import '../../domain/entities/host.dart';
import '../terminal/host_key_prompt.dart';

/// Home screen: saved hosts grouped by folder, with search, quick connect, and
/// per-host edit/delete. Tapping a host connects with one click using its
/// vault-stored credential.
class HostListPage extends ConsumerStatefulWidget {
  const HostListPage({super.key});

  @override
  ConsumerState<HostListPage> createState() => _HostListPageState();
}

class _HostListPageState extends ConsumerState<HostListPage> {
  String _query = '';
  final Set<String> _collapsed = {};

  Future<void> _connect(Host host) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final verifier = buildHostKeyVerifier(ref.read(knownHostsProvider));
    try {
      final request = await ref.read(hostServiceProvider).buildRequest(host);
      ref.read(sessionsProvider.notifier).open(request, verifyHostKey: verifier);
      router.goNamed('terminal');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Cannot connect: $e')));
    }
  }

  Future<void> _confirmDelete(Host host) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete host?'),
        content: Text('"${host.label}" and its stored secret will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(hostServiceProvider).deleteHost(host);
    }
  }

  String _groupOf(Host h) =>
      (h.groupName?.isNotEmpty ?? false) ? h.groupName! : kDefaultGroup;

  /// Groups + sorts hosts, applying the search filter. Hosts without a group
  /// fall under the default group.
  Map<String, List<Host>> _grouped(List<Host> hosts) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? [...hosts]
        : hosts.where((h) {
            return h.label.toLowerCase().contains(q) ||
                h.hostname.toLowerCase().contains(q) ||
                h.username.toLowerCase().contains(q);
          }).toList();

    filtered.sort((a, b) {
      final g = _groupOf(a).compareTo(_groupOf(b));
      return g != 0 ? g : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    final map = <String, List<Host>>{};
    for (final h in filtered) {
      map.putIfAbsent(_groupOf(h), () => []).add(h);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final hosts = ref.watch(hostsProvider);

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search hosts',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: hosts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          final grouped = _grouped(list);
          if (grouped.isEmpty) {
            return const Center(child: Text('No hosts match your search.'));
          }
          return ListView(
            children: [
              for (final entry in grouped.entries) ...[
                _GroupHeader(
                  name: entry.key,
                  count: entry.value.length,
                  collapsed: _collapsed.contains(entry.key),
                  onTap: () => setState(() {
                    if (!_collapsed.remove(entry.key)) {
                      _collapsed.add(entry.key);
                    }
                  }),
                ),
                if (!_collapsed.contains(entry.key))
                  for (final host in entry.value)
                    _HostTile(
                      host: host,
                      onTap: () => _connect(host),
                      onEdit: () =>
                          context.pushNamed('editHost', extra: host),
                      onDelete: () => _confirmDelete(host),
                    ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('newHost'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.name,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 20,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${name.toUpperCase()}  ($count)',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostTile extends StatelessWidget {
  const _HostTile({
    required this.host,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Host host;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        host.authMethod == AuthMethod.sshKey ? Icons.key : Icons.dns_outlined,
      ),
      title: Text(host.label),
      subtitle: Text(host.username.isEmpty
          ? '${host.hostname}:${host.port}'
          : '${host.username}@${host.hostname}:${host.port}'),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('No saved hosts yet.'),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () => context.pushNamed('newHost'),
                icon: const Icon(Icons.add),
                label: const Text('Add host'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed('connect'),
                icon: const Icon(Icons.bolt),
                label: const Text('Quick Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
