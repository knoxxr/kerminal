import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/account_providers.dart';
import '../../application/providers.dart';
import '../../data/remote/identity_repository.dart';
import '../../domain/entities/host.dart';

/// Opens the "share this host with a colleague" bottom sheet.
void showShareHostSheet(BuildContext context, Host host) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShareHostSheet(host: host),
  );
}

class _ShareHostSheet extends ConsumerStatefulWidget {
  const _ShareHostSheet({required this.host});
  final Host host;

  @override
  ConsumerState<_ShareHostSheet> createState() => _ShareHostSheetState();
}

class _ShareHostSheetState extends ConsumerState<_ShareHostSheet> {
  final _email = TextEditingController();
  List<PublicIdentity> _recipients = const [];
  bool _loading = true;
  bool _busy = false;
  String? _message;

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
      final r = await sync.recipientsOf(widget.host.id);
      if (mounted) setState(() => _recipients = r);
    } catch (_) {
      // Host may not be synced yet; leave recipients empty.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        setState(() => _message = 'No Kerminal account for "$email".');
        return;
      }
      await sync.shareHost(widget.host.id, colleague);
      _email.clear();
      final r = await sync.recipientsOf(widget.host.id);
      if (mounted) setState(() => _recipients = r);
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unshare(PublicIdentity who) async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    setState(() => _busy = true);
    try {
      await sync.unshareHost(widget.host.id, who.userId);
      final r = await sync.recipientsOf(widget.host.id);
      if (mounted) setState(() => _recipients = r);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudReady =
        ref.watch(accountControllerProvider).asData?.value is AccountUnlocked;

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
            'Share "${widget.host.label}"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'The colleague must have a Kerminal account. They will see this '
            'host in their list, decrypted only on their device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else ...[
            if (_recipients.isEmpty)
              const Text('Not shared with anyone yet.')
            else
              for (final r in _recipients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text(r.email),
                  trailing: IconButton(
                    tooltip: 'Unshare',
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
                      decoration: const InputDecoration(
                        labelText: "Colleague's email",
                      ),
                      onSubmitted: (_) => _share(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _share,
                    child: const Text('Share'),
                  ),
                ],
              ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
