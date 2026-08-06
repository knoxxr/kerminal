import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/account_providers.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../data/crypto/backup_crypto.dart';
import '../../data/remote/feedback_service.dart';
import '../../application/update_providers.dart';
import '../../application/update_service.dart';
import 'contact_sheet.dart';

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
          Text('Account & Sync',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _AccountSection(),
          const SizedBox(height: 28),
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
          Text('Version & updates',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _UpdateSection(),
          const SizedBox(height: 28),
          Text('Backup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _BackupSection(),
          const SizedBox(height: 28),
          Text('Support', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _SupportSection(),
        ],
      ),
    );
  }
}

/// In-app inquiry form. Hidden in local-only builds: the message is relayed by a
/// server-side function (which holds the destination address), so without cloud
/// credentials there is nothing to send through.
class _SupportSection extends ConsumerWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSend = ref.watch(feedbackServiceProvider) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          canSend
              ? 'Send a question, bug report or request straight to the '
                  'maintainer.'
              : 'This build has no cloud connection, so in-app messages are '
                  'unavailable. Please open an issue on GitHub instead.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (canSend)
              FilledButton.tonalIcon(
                onPressed: () => showContactSheet(context),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contact us'),
              ),
            if (canSend) const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/knoxxr/kerminal/issues'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('GitHub Issues'),
            ),
          ],
        ),
      ],
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
          'Save all your servers to one file, protected by a passphrase you '
          'choose. Passwords and SSH keys are included, so keep the file safe. '
          'Use it to move to another device or to recover after reinstalling.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _export(context, ref),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Save to file…'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _import(context, ref),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Restore from file…'),
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
        content: Text('Exported to ${location.path}'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
        SnackBar(content: Text('Imported $count host(s).')),
      );
    } on BackupDecryptException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Wrong passphrase, or the file is corrupted.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
        title: Text(confirm ? 'Set backup passphrase' : 'Enter passphrase'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pass,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Passphrase'),
                validator: (v) => (v == null || v.length < 4)
                    ? 'At least 4 characters'
                    : null,
              ),
              if (confirm)
                TextFormField(
                  controller: pass2,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm passphrase'),
                  validator: (v) =>
                      v != pass.text ? 'Passphrases do not match' : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, pass.text);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Shows the current version, a "check for updates" action, and — when the
/// remote manifest advertises a newer version — a card with release notes and
/// a download button.
/// Compact account status + entry point to the full account screen.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountControllerProvider);
    final (title, subtitle, icon) = state.maybeWhen(
      orElse: () => ('Account', 'Loading…', Icons.cloud_outlined),
      data: (account) => switch (account) {
        AccountCloudDisabled() => (
            'Cloud not configured',
            'This build has no sync credentials',
            Icons.cloud_off_outlined,
          ),
        AccountSignedOut() => (
            'Sign in to sync',
            'Back up & share hosts across devices',
            Icons.cloud_outlined,
          ),
        AccountLocked(:final email) => (
            email,
            'Locked — enter passphrase to unlock',
            Icons.lock_outline,
          ),
        AccountUnlocked(:final identity) => (
            identity.email,
            'Signed in · encryption unlocked',
            Icons.verified_user_outlined,
          ),
      },
    );

    final disabled = state.maybeWhen(
      data: (a) => a is AccountCloudDisabled,
      orElse: () => false,
    );

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: disabled ? null : const Icon(Icons.chevron_right),
        onTap: disabled ? null : () => context.pushNamed('account'),
      ),
    );
  }
}

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
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Update check failed: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
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
