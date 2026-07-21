import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings.dart';

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
        ],
      ),
    );
  }
}
