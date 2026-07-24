import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/account_providers.dart';
import '../../application/known_hosts.dart';
import '../../application/providers.dart';
import '../../application/sessions.dart';
import '../../data/remote/host_sync_service.dart';
import '../../domain/entities/host.dart';
import '../terminal/host_key_prompt.dart';
import 'history_sheets.dart';
import 'share_host_sheet.dart';

/// The searchable, grouped host list. Reused both as the main screen body
/// (full page) and as the collapsible sidebar on the terminal workspace.
///
/// Tapping a host connects it (opens a session). When [navigateAfterConnect] is
/// true the caller is taken to the terminal route; otherwise [onConnected] is
/// invoked (used by the sidebar, which is already on the terminal screen).
class HostListView extends ConsumerStatefulWidget {
  const HostListView({
    super.key,
    this.navigateAfterConnect = true,
    this.onConnected,
  });

  final bool navigateAfterConnect;
  final VoidCallback? onConnected;

  @override
  ConsumerState<HostListView> createState() => _HostListViewState();
}

class _HostListViewState extends ConsumerState<HostListView> {
  String _query = '';
  final Set<String> _collapsed = {};

  Future<void> _connect(Host host) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final verifier = buildHostKeyVerifier(ref.read(knownHostsProvider));
    try {
      final request = await ref.read(hostServiceProvider).buildRequest(host);
      ref.read(sessionsProvider.notifier).open(request, verifyHostKey: verifier);
      if (widget.navigateAfterConnect) {
        router.goNamed('terminal');
      } else {
        widget.onConnected?.call();
      }
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
      final ownedByMe = ref.read(shareInfoProvider)[host.id]?.ownedByMe ?? true;
      await ref.read(hostServiceProvider).deleteHost(host);
      if (ownedByMe) {
        try {
          await ref.read(hostSyncServiceProvider)?.pushDelete(host.id);
        } catch (_) {/* offline / locked */}
      }
    }
  }

  Future<void> _acceptInvite(HostInvitation invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    try {
      await sync.acceptInvitation(invite.hostId);
      messenger.showSnackBar(
        SnackBar(content: Text('"${invite.summary}" 를 목록에 추가했습니다.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('수신 실패: $e')));
    }
  }

  Future<void> _declineInvite(HostInvitation invite) async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    try {
      await sync.declineInvitation(invite.hostId);
    } catch (_) {/* transient */}
  }

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
    final account = ref.watch(accountControllerProvider).value;
    final signedIn = account is AccountLocked || account is AccountUnlocked;

    final invitations = ref.watch(pendingInvitationsProvider);

    // Keep realtime sync alive while this list is shown.
    ref.watch(syncRealtimeProvider);

    return Column(
      children: [
        for (final invite in invitations)
          _InvitationCard(
            invite: invite,
            onAccept: () => _acceptInvite(invite),
            onDecline: () => _declineInvite(invite),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
        Expanded(
          child: hosts.when(
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
                          signedIn: signedIn,
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
        ),
      ],
    );
  }
}

/// A pending share invitation shown as a message at the top of the host list.
/// The host is NOT in the list until the user taps "수신" (accept).
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  final HostInvitation invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mail_outline,
                    size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${invite.ownerEmail} 님이 호스트를 공유했습니다',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                invite.summary,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSecondaryContainer.withValues(alpha: 0.85),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDecline, child: const Text('거절')),
                const SizedBox(width: 4),
                FilledButton(onPressed: onAccept, child: const Text('수신')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Low-emphasis "owned by me" marker — most hosts are mine, so this stays
/// quiet (muted icon + small text, no filled background) to avoid clutter.
class _OwnerMark extends StatelessWidget {
  const _OwnerMark();

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_outlined, size: 13, color: color),
        const SizedBox(width: 3),
        Text('소유자', style: TextStyle(fontSize: 10.5, color: color)),
      ],
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
    this.signedIn = false,
  });

  final Host host;
  final HostShareInfo? share;
  final bool signedIn;
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

    final tile = ListTile(
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
          ] else if (signedIn) ...[
            const SizedBox(width: 8),
            const _OwnerMark(),
            if (share?.sharedOut ?? false) ...[
              const SizedBox(width: 6),
              const _ShareChip(icon: Icons.ios_share, label: '공유함'),
            ],
          ],
        ],
      ),
      subtitle: Text(subtitle),
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

    // Connect on double-click/double-tap only (avoids accidental connects from
    // a single stray click).
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onDoubleTap: onTap, child: tile),
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
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => context.pushNamed('newHost'),
                icon: const Icon(Icons.add),
                label: const Text('Add host'),
              ),
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
