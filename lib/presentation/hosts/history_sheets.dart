import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/remote/host_sync_service.dart';
import '../../domain/entities/host.dart';

String _opLabel(String op) => switch (op) {
  'create' => '생성',
  'update' => '수정',
  'delete' => '삭제',
  'rollback' => '롤백',
  _ => op,
};

String _when(String iso) =>
    iso.length >= 19 ? iso.substring(0, 19).replaceFirst('T', ' ') : iso;

/// Opens the change-history sheet for a host (owner only).
void showHistorySheet(BuildContext context, Host host) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HistorySheet(host: host),
  );
}

class _HistorySheet extends ConsumerStatefulWidget {
  const _HistorySheet({required this.host});
  final Host host;

  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  List<HostVersion> _items = const [];
  bool _loading = true;
  int? _busyVersion;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final items = await sync.fetchHistory(widget.host.id);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // leave empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(HostVersion v) async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    setState(() => _busyVersion = v.version);
    try {
      await sync.rollbackTo(widget.host.id, v.version);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('버전 ${v.version}로 되돌렸습니다.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyVersion = null);
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
          Text('"${widget.host.label}" 변경 이력',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            const Text('이력이 없습니다. (로그인·잠금 해제 후 동기화된 호스트만 이력이 쌓입니다.)')
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final v in _items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${v.version}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(
                        '${_opLabel(v.op)}${v.summary == null ? '' : ' · ${v.summary}'}',
                      ),
                      subtitle: Text(
                        [_when(v.createdAt), if (v.editorEmail.isNotEmpty) v.editorEmail]
                            .join('  ·  '),
                      ),
                      trailing: _busyVersion == v.version
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : v.hasSnapshot
                              ? TextButton(
                                  onPressed: () => _restore(v),
                                  child: const Text('복원'),
                                )
                              : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the "recently deleted" (trash) sheet — restore soft-deleted hosts.
void showTrashSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _TrashSheet(),
  );
}

class _TrashSheet extends ConsumerStatefulWidget {
  const _TrashSheet();

  @override
  ConsumerState<_TrashSheet> createState() => _TrashSheetState();
}

class _TrashSheetState extends ConsumerState<_TrashSheet> {
  List<DeletedHost> _items = const [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final items = await sync.fetchDeleted();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // leave empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(DeletedHost h) async {
    final sync = ref.read(hostSyncServiceProvider);
    if (sync == null) return;
    setState(() => _busyId = h.hostId);
    try {
      await sync.restoreDeleted(h.hostId);
      await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
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
          Text('최근 삭제한 호스트',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            const Text('삭제된 호스트가 없습니다.')
          else
            for (final h in _items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline),
                title: Text(h.summary),
                trailing: _busyId == h.hostId
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _restore(h),
                        child: const Text('복원'),
                      ),
              ),
        ],
      ),
    );
  }
}
