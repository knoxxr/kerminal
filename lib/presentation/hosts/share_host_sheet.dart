import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/account_providers.dart';
import '../../application/providers.dart';
import '../../data/remote/host_sync_service.dart';
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
      final r = await sync.recipientsOf(widget.host.id);
      if (mounted) setState(() => _recipients = r);
    } catch (_) {
      // Host may not be synced yet; leave recipients empty.
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
        // Invalid invitee — tell the sharer clearly so they can fix the address.
        _setMessage(
          '"$email" 로 가입된 Kerminal 계정이 없습니다. 이메일을 확인하세요.',
          isError: true,
        );
        return;
      }
      await sync.shareHost(widget.host.id, colleague);
      _email.clear();
      final r = await sync.recipientsOf(widget.host.id);
      if (mounted) {
        setState(() => _recipients = r);
        _setMessage('${colleague.email} 님을 초대했습니다. 상대가 수신하면 목록에 추가됩니다.');
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
      await sync.unshareHost(widget.host.id, who.identity.userId);
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
            '초대할 동료는 Kerminal 계정이 있어야 합니다. 초대를 보내면 상대에게 '
            '메시지로 표시되고, 상대가 "수신"을 눌러야 자신의 목록에 추가됩니다.',
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
              const Text('아직 아무에게도 공유하지 않았습니다.')
            else
              for (final r in _recipients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    r.accepted ? Icons.person : Icons.hourglass_empty,
                    color: r.accepted
                        ? null
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                  title: Text(r.identity.email),
                  subtitle: Text(r.accepted ? '수신함' : '초대함 · 수신 대기'),
                  trailing: IconButton(
                    tooltip: '공유 취소',
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
                        labelText: '동료 이메일',
                      ),
                      onSubmitted: (_) => _share(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _share,
                    child: const Text('초대'),
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
