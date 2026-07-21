import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable app settings.
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.dark, this.fontSize = 14});

  final ThemeMode themeMode;
  final double fontSize;

  AppSettings copyWith({ThemeMode? themeMode, double? fontSize}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        fontSize: fontSize ?? this.fontSize,
      );
}

/// Provides the [SharedPreferences] instance. Overridden in `main` with the
/// preloaded instance so the settings controller can read synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Loads and persists [AppSettings].
class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'settings.themeMode';
  static const _kFont = 'settings.fontSize';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final themeIdx = _prefs.getInt(_kTheme) ?? ThemeMode.dark.index;
    final font = _prefs.getDouble(_kFont) ?? 14.0;
    return AppSettings(
      themeMode: ThemeMode.values[themeIdx],
      fontSize: font,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_kTheme, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(8.0, 28.0);
    await _prefs.setDouble(_kFont, clamped);
    state = state.copyWith(fontSize: clamped);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
