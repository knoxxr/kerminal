import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/ssh/ssh_config_parser.dart';
import '../../data/ssh/ssh_config_reader.dart';
import '../../domain/entities/host.dart';

/// Offers to import servers from `~/.ssh/config`.
///
/// Typing 40 existing hosts by hand is where most people give up, so this is
/// mostly an onboarding shortcut. Nothing is imported until the user confirms,
/// and the sheet shows exactly what will be added.
Future<void> showImportSshConfigSheet(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ImportSheet(),
    );

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet();

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  List<SshConfigHost>? _found;
  final _selected = <String>{};
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = await readSshConfig();
    final hosts =
        content == null ? <SshConfigHost>[] : const SshConfigParser().parse(content);
    // Anything already saved under the same address+user is skipped by default,
    // so running this twice doesn't produce duplicates.
    final existing = ref.read(hostsProvider).asData?.value ?? const <Host>[];
    bool isNew(SshConfigHost h) => !existing.any(
          (e) =>
              e.hostname.toLowerCase() == h.hostname.toLowerCase() &&
              e.port == h.port &&
              e.username.toLowerCase() == h.username.toLowerCase(),
        );
    if (!mounted) return;
    setState(() {
      _found = hosts;
      _selected
        ..clear()
        ..addAll(hosts.where(isNew).map((h) => h.alias));
      _loading = false;
    });
  }

  Future<void> _import() async {
    final chosen =
        _found!.where((h) => _selected.contains(h.alias)).toList();
    if (chosen.isEmpty) return;
    setState(() => _importing = true);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(hostServiceProvider);
    var added = 0;
    for (final h in chosen) {
      try {
        // No secret: the config only points at a key file, and reading private
        // keys off disk without the user's say-so would be wrong. They fill in
        // the password or key when they first connect.
        await service.saveHost(
          label: h.alias,
          hostname: h.hostname,
          port: h.port,
          username: h.username,
          groupName: 'Imported',
          authMethod:
              h.identityFile != null ? AuthMethod.sshKey : AuthMethod.password,
        );
        added++;
      } catch (_) {/* skip the entry, keep importing the rest */}
    }
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? 'Nothing was imported.'
              : 'Imported $added server(s). Add a password or key before '
                  'connecting.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import from ~/.ssh/config',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!sshConfigImportSupported)
            const Text(
              'This is only available on desktop — phones have no accessible '
              '~/.ssh folder.',
            )
          else if (_found!.isEmpty)
            const Text(
              'No servers found. Either ~/.ssh/config does not exist, or it '
              'only contains patterns such as "Host *".',
            )
          else ...[
            Text(
              'Passwords and keys are not read from disk — add them when you '
              'first connect.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final h in _found!)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(h.alias),
                      onChanged: (on) => setState(() {
                        if (on ?? false) {
                          _selected.add(h.alias);
                        } else {
                          _selected.remove(h.alias);
                        }
                      }),
                      title: Text(h.alias),
                      subtitle: Text(
                        [
                          h.username.isEmpty
                              ? '${h.hostname}:${h.port}'
                              : '${h.username}@${h.hostname}:${h.port}',
                          // Kerminal cannot chain through a bastion yet, so say
                          // so instead of importing something that won't work.
                          if (h.needsJumpHost)
                            'needs jump host ${h.proxyJump} — not supported yet',
                        ].join('  ·  '),
                        style: TextStyle(
                          color: h.needsJumpHost ? scheme.error : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _importing ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_loading || _importing || _selected.isEmpty)
                    ? null
                    : _import,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _selected.isEmpty
                      ? 'Import'
                      : 'Import ${_selected.length} server(s)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
