import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/account_providers.dart';
import '../../application/providers.dart';
import '../../data/remote/host_sync_service.dart';
import '../../data/remote/identity_repository.dart';
import '../../domain/entities/host.dart';

/// Shares every host in a group with a colleague at once. [hosts] should be the
/// hosts of the group that the current user owns (shared-in hosts can't be
/// re-shared). Sharing/unsharing simply fans out over each host, reusing the
/// per-host invitation flow.
void showShareGroupSheet(
  BuildContext context,
  String groupName,
  List<Host> hosts,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShareGroupSheet(groupName: groupName, hosts: hosts),
  );
}

class _ShareGroupSheet extends ConsumerStatefulWidget {
  const _ShareGroupSheet({required this.groupName, required this.hosts});
  final String groupName;
  final List<Host> hosts;

  @override
  ConsumerState<_ShareGroupSheet> createState() => _ShareGroupSheetState();
}

class _ShareGroupSheetState extends ConsumerState<_ShareGroupSheet> {
  final _email = TextEditingController();
  // Colleagues shared into EVERY host of the group (the group's members).
  List<ShareRecipient> _recipients = const [];
  bool _loading = true;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) {
      setState(() {
        _loading = false;
        _message = 'Sign in and unlock to share hosts.';
      });
      return;
    }
    try {
      final identities = <String, PublicIdentity>{};
      final presentCount = <String, int>{};
      final acceptedAll = <String, bool>{};
      for (final h in widget.hosts) {
        List<ShareRecipient> r;
        try {
          r = await sync.recipientsOf(h.id);
        } catch (_) {
          r = const []; // host may not be synced yet
        }
        for (final x in r) {
          final id = x.identity.userId;
          identities[id] = x.identity;
          presentCount[id] = (presentCount[id] ?? 0) + 1;
          acceptedAll[id] = (acceptedAll[id] ?? true) && x.accepted;
        }
      }
      final n = widget.hosts.length;
      final recips = [
        for (final e in identities.entries)
          if (presentCount[e.key] == n)
            ShareRecipient(
              identity: e.value,
              accepted: acceptedAll[e.key] ?? false,
            ),
      ];
      if (mounted) setState(() => _recipients = recips);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setMessage(String? text, {bool isError = false}) {
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  Future<void> _share() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    final ident = ref.read(identityRepositoryProvider);
    final sync = ref.read(hostSyncServiceProvider);
    if (ident == null || sync == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final colleague = await ident.findByEmail(email);
      if (colleague == null) {
        _setMessage(
          'No Kerminal account is registered for "$email". '
          'Check the address.',
          isError: true,
        );
        return;
      }
      var ok = 0;
      for (final h in widget.hosts) {
        try {
          await sync.shareHost(h.id, colleague);
          ok++;
        } catch (_) {
          // skip hosts that fail (e.g. not owned / not synced)
        }
      }
      _email.clear();
      await _load();
      if (mounted) {
        _setMessage(
          'Invited ${colleague.email} to $ok host(s) in '
          '"${widget.groupName}". They appear in their list once accepted.',
        );
      }
    } catch (e) {
      if (mounted) _setMessage('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unshare(ShareRecipient who) async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    setState(() => _busy = true);
    try {
      for (final h in widget.hosts) {
        try {
          await sync.unshareHost(h.id, who.identity.userId);
        } catch (_) {}
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudReady =
        ref.watch(accountControllerProvider).asData?.value is AccountUnlocked;
    final n = widget.hosts.length;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share group · "${widget.groupName}" ($n host(s))',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Invites one colleague to every host in this group that you own. '
            'Only the hosts they accept are added to their list.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            if (_recipients.isEmpty)
              const Text('No one has been invited to this group yet.')
            else
              for (final r in _recipients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    r.accepted ? Icons.group : Icons.hourglass_empty,
                    color: r.accepted
                        ? null
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                  title: Text(r.identity.email),
                  subtitle: Text(
                    r.accepted ? 'Accepted all' : 'Invited · awaiting reply',
                  ),
                  trailing: IconButton(
                    tooltip: 'Stop sharing group',
                    icon: const Icon(Icons.close),
                    onPressed: _busy ? null : () => _unshare(r),
                  ),
                ),
            const SizedBox(height: 12),
            if (cloudReady)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(labelText: 'Colleague email'),
                      onSubmitted: (_) => _share(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _share,
                    child: const Text('Invite'),
                  ),
                ],
              ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(
                color: _messageIsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
