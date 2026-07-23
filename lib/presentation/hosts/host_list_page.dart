import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/known_hosts.dart';
import '../../application/providers.dart';
import '../../application/sessions.dart';
import '../../application/update_providers.dart';
import '../../data/remote/host_sync_service.dart';
import '../../domain/entities/host.dart';
import '../terminal/host_key_prompt.dart';
import 'history_sheets.dart';
import 'share_host_sheet.dart';

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
      final ownedByMe =
          ref.read(shareInfoProvider)[host.id]?.ownedByMe ?? true;
      await ref.read(hostServiceProvider).deleteHost(host);
      // Best-effort cloud soft-delete; local removal already happened. Only the
      // owner may delete server-side (shared-in hosts stay for other users).
      if (ownedByMe) {
        try {
          await ref.read(hostSyncServiceProvider)?.pushDelete(host.id);
        } catch (_) {/* offline / locked */}
      }
    }
  }

  /// Duplicates a host into my own list. Used to make an editable copy of a
  /// read-only shared host (the copy is mine — I can edit and re-share it).
  Future<void> _copyHost(Host host) async {
    final messenger = ScaffoldMessenger.of(context);
    final svc = ref.read(hostServiceProvider);
    final p = await svc.readPayload(host);
    final saved = await svc.saveHost(
      label: '${host.label} (copy)',
      hostname: p.hostname,
      port: p.port,
      username: p.username,
      groupName: host.groupName,
      authMethod: p.authMethod,
      password: p.password,
      privateKeyPem: p.privateKeyPem,
      passphrase: p.passphrase,
    );
    try {
      await ref.read(hostSyncServiceProvider)?.pushHost(saved);
    } catch (_) {/* offline / locked — reconciled on next sync */}
    messenger.showSnackBar(
      SnackBar(content: Text('"${saved.label}" 를 내 목록으로 복사했습니다.')),
    );
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
    final shareInfo = ref.watch(shareInfoProvider);

    // Keep realtime sync alive while signed in + unlocked (pull + labels
    // refresh automatically on any change).
    ref.watch(syncRealtimeProvider);

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
                      share: shareInfo[host.id],
                      onTap: () => _connect(host),
                      onEdit: () =>
                          context.pushNamed('editHost', extra: host),
                      onDelete: () => _confirmDelete(host),
                      onShare: () => showShareHostSheet(context, host),
                      onCopy: () => _copyHost(host),
                      onHistory: () => showHistorySheet(context, host),
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

class _ShareChip extends StatelessWidget {
  const _ShareChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer),
          ),
        ],
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
    required this.onShare,
    required this.onCopy,
    required this.onHistory,
    this.share,
  });

  final Host host;
  final HostShareInfo? share;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final sharedIn = share != null && !share!.ownedByMe;
    final subtitle = host.username.isEmpty
        ? '${host.hostname}:${host.port}'
        : '${host.username}@${host.hostname}:${host.port}';

    return ListTile(
      leading: Icon(
        host.authMethod == AuthMethod.sshKey ? Icons.key : Icons.dns_outlined,
      ),
      title: Row(
        children: [
          Flexible(child: Text(host.label, overflow: TextOverflow.ellipsis)),
          if (sharedIn) ...[
            const SizedBox(width: 8),
            _ShareChip(
              icon: Icons.people_alt_outlined,
              label: '공유받음 · ${share!.ownerEmail ?? '동료'}',
            ),
          ] else if (share?.sharedOut ?? false) ...[
            const SizedBox(width: 8),
            const _ShareChip(icon: Icons.ios_share, label: '공유함'),
          ],
        ],
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'edit':
              onEdit();
            case 'share':
              onShare();
            case 'copy':
              onCopy();
            case 'history':
              onHistory();
            default:
              onDelete();
          }
        },
        // A host shared *to* me is read-only: I can copy it into my own list
        // (then edit the copy freely) but can't change or re-share the original.
        itemBuilder: (context) => sharedIn
            ? const [PopupMenuItem(value: 'copy', child: Text('내 목록으로 복사'))]
            : const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'share', child: Text('Share…')),
                PopupMenuItem(value: 'copy', child: Text('Duplicate')),
                PopupMenuItem(value: 'history', child: Text('History')),
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
