import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/settings.dart';
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
          title: const Text('Kominal'),
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
