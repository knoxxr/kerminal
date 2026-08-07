import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable app settings.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.fontSize = 14,
    this.terminalPaletteId = 'default',
  });

  final ThemeMode themeMode;
  final double fontSize;

  /// Id of the selected terminal colour scheme (see `TerminalPalette`). Stored
  /// as a string rather than an index so reordering the list can't silently
  /// change everyone's choice.
  final String terminalPaletteId;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? fontSize,
    String? terminalPaletteId,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        fontSize: fontSize ?? this.fontSize,
        terminalPaletteId: terminalPaletteId ?? this.terminalPaletteId,
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
  static const _kPalette = 'settings.terminalPalette';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final themeIdx = _prefs.getInt(_kTheme) ?? ThemeMode.dark.index;
    final font = _prefs.getDouble(_kFont) ?? 14.0;
    return AppSettings(
      // A stored index out of range (downgrade after a Flutter change) must not
      // crash the app on start.
      themeMode: themeIdx >= 0 && themeIdx < ThemeMode.values.length
          ? ThemeMode.values[themeIdx]
          : ThemeMode.dark,
      fontSize: font,
      terminalPaletteId: _prefs.getString(_kPalette) ?? 'default',
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

  Future<void> setTerminalPalette(String id) async {
    await _prefs.setString(_kPalette, id);
    state = state.copyWith(terminalPaletteId: id);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
