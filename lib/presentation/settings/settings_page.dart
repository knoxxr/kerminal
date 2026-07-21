import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../data/crypto/backup_crypto.dart';
import '../../application/update_providers.dart';
import '../../application/update_service.dart';

/// App preferences: terminal theme mode and font size, persisted immediately.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => controller.setThemeMode(s.first),
          ),
          const SizedBox(height: 28),
          Text('Terminal', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.format_size, size: 20),
              Expanded(
                child: Slider(
                  min: 8,
                  max: 28,
                  divisions: 20,
                  label: settings.fontSize.round().toString(),
                  value: settings.fontSize,
                  onChanged: (v) => controller.setFontSize(v),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('${settings.fontSize.round()}',
                    textAlign: TextAlign.end),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              r'$ echo "font preview"',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: settings.fontSize,
                color: Colors.greenAccent,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('About & Updates',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _UpdateSection(),
          const SizedBox(height: 28),
          Text('Backup & Share',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _BackupSection(),
        ],
      ),
    );
  }
}

/// Encrypted export/import of hosts. The backup is passphrase-encrypted, so it
/// can be shared safely (e.g. uploaded to Google Drive) — only someone with the
/// passphrase can import it.
class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '호스트를 암호로 암호화한 파일로 내보내 Google Drive 등으로 공유하고, '
          '같은 암호로 가져올 수 있습니다. 비밀번호·키도 포함됩니다.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _export(context, ref),
              icon: const Icon(Icons.lock_outline),
              label: const Text('암호화 내보내기'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _import(context, ref),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('가져오기'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final passphrase = await _askPassphrase(context, confirm: true);
    if (passphrase == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final envelope =
          await ref.read(hostServiceProvider).exportEncrypted(passphrase);
      final location = await getSaveLocation(
        suggestedName: 'kerminal-hosts.kerminal',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Kerminal backup', extensions: ['kerminal']),
        ],
      );
      if (location == null) return; // cancelled
      final data = utf8.encode(envelope);
      final file = XFile.fromData(
        data,
        mimeType: 'application/json',
        name: 'kerminal-hosts.kerminal',
      );
      await file.saveTo(location.path);
      messenger.showSnackBar(SnackBar(
        content: Text('내보냄: ${location.path}\nGoogle Drive에 올려 공유하세요.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Kerminal backup', extensions: ['kerminal', 'json']),
      ],
    );
    if (file == null) return;
    final content = await file.readAsString();
    if (!context.mounted) return;
    final passphrase = await _askPassphrase(context, confirm: false);
    if (passphrase == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count =
          await ref.read(hostServiceProvider).importEncrypted(content, passphrase);
      messenger.showSnackBar(
        SnackBar(content: Text('$count개 호스트를 가져왔습니다.')),
      );
    } on BackupDecryptException {
      messenger.showSnackBar(
        const SnackBar(content: Text('암호가 틀리거나 손상된 파일입니다.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
    }
  }

  /// Prompts for a passphrase. When [confirm] is true, requires the two entries
  /// to match. Returns null if cancelled.
  Future<String?> _askPassphrase(BuildContext context,
      {required bool confirm}) {
    final pass = TextEditingController();
    final pass2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirm ? '백업 암호 설정' : '백업 암호 입력'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pass,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: '암호(passphrase)'),
                validator: (v) =>
                    (v == null || v.length < 4) ? '4자 이상' : null,
              ),
              if (confirm)
                TextFormField(
                  controller: pass2,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '암호 확인'),
                  validator: (v) => v != pass.text ? '암호가 일치하지 않습니다' : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, pass.text);
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

/// Shows the current version, a "check for updates" action, and — when the
/// remote manifest advertises a newer version — a card with release notes and
/// a download button.
class _UpdateSection extends ConsumerWidget {
  const _UpdateSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);
    final update = ref.watch(updateCheckProvider);

    final version = packageInfo.maybeWhen(
      data: (info) => 'v${info.version} (${info.buildNumber})',
      orElse: () => '…',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('Kerminal'),
          subtitle: Text(version),
          trailing: update.isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: () => ref.invalidate(updateCheckProvider),
                  child: const Text('Check'),
                ),
        ),
        update.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('Update check failed.'),
          data: (info) {
            if (info == null) return const SizedBox.shrink();
            if (!info.updateAvailable) {
              return const Text('You are on the latest version.');
            }
            return _UpdateAvailableCard(info: info);
          },
        ),
      ],
    );
  }
}

class _UpdateAvailableCard extends StatelessWidget {
  const _UpdateAvailableCard({required this.info});

  final UpdateInfo info;

  Future<void> _download(BuildContext context) async {
    final url = info.downloadUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update),
                const SizedBox(width: 8),
                Text('Update available — v${info.latestVersion}',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            if (info.notes != null && info.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(info.notes!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    info.downloadUrl == null ? null : () => _download(context),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
