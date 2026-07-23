import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/remote/host_sync_service.dart';

/// Opens the "review colleagues' proposed edits" sheet.
void showProposalsSheet(BuildContext context, List<HostProposal> proposals) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProposalsSheet(initial: proposals),
  );
}

class _ProposalsSheet extends ConsumerStatefulWidget {
  const _ProposalsSheet({required this.initial});
  final List<HostProposal> initial;

  @override
  ConsumerState<_ProposalsSheet> createState() => _ProposalsSheetState();
}

class _ProposalsSheetState extends ConsumerState<_ProposalsSheet> {
  late List<HostProposal> _items = widget.initial;
  String? _busyVersionId;

  Future<void> _refresh() async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    final latest = await sync.fetchProposals();
    ref.read(pendingProposalsProvider.notifier).set(latest);
    if (mounted) setState(() => _items = latest);
  }

  Future<void> _decide(HostProposal p, {required bool accept}) async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    setState(() => _busyVersionId = p.versionId);
    try {
      if (accept) {
        await sync.acceptProposal(p);
      } else {
        await sync.rejectProposal(p.versionId);
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyVersionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '제안된 수정',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('검토할 제안이 없습니다.'),
            )
          else
            for (final p in _items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note),
                title: Text(p.hostLabel),
                subtitle: Text('${p.editorEmail} 님의 제안'),
                trailing: _busyVersionId == p.versionId
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _decide(p, accept: false),
                            child: const Text('무시'),
                          ),
                          FilledButton(
                            onPressed: () => _decide(p, accept: true),
                            child: const Text('동기화'),
                          ),
                        ],
                      ),
              ),
        ],
      ),
    );
  }
}
