import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Selectable terminal colour schemes.
///
/// xterm only ships `defaultTheme` and `whiteOnBlack`, and [TerminalTheme]
/// requires all 23 colours, so the well-known palettes are spelled out here.
/// Values are the schemes' published ANSI definitions.
class TerminalPalette {
  const TerminalPalette({
    required this.id,
    required this.name,
    required this.theme,
  });

  /// Stable key persisted in settings — never change it for an existing
  /// palette, or users lose their choice on upgrade.
  final String id;

  /// Shown in the settings picker.
  final String name;

  final TerminalTheme theme;

  /// All palettes, in the order they appear in settings.
  static const all = <TerminalPalette>[
    TerminalPalette(id: 'default', name: 'Kerminal', theme: _kerminal),
    TerminalPalette(id: 'dracula', name: 'Dracula', theme: _dracula),
    TerminalPalette(
      id: 'solarized-dark',
      name: 'Solarized Dark',
      theme: _solarizedDark,
    ),
    TerminalPalette(
      id: 'solarized-light',
      name: 'Solarized Light',
      theme: _solarizedLight,
    ),
    TerminalPalette(id: 'gruvbox-dark', name: 'Gruvbox Dark', theme: _gruvbox),
    TerminalPalette(id: 'nord', name: 'Nord', theme: _nord),
  ];

  static const fallback = all[0];

  /// The palette stored under [id], or [fallback] when it is unknown (an older
  /// build, or a value from a newer one).
  static TerminalPalette byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return fallback;
  }

  // The scheme that shipped before palettes were selectable, so existing users
  // see no change unless they pick another.
  static const _kerminal = TerminalThemes.defaultTheme;

  static const _dracula = TerminalTheme(
    cursor: Color(0xFFF8F8F2),
    selection: Color(0x4444475A),
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF282A36),
    black: Color(0xFF21222C),
    red: Color(0xFFFF5555),
    green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C),
    blue: Color(0xFFBD93F9),
    magenta: Color(0xFFFF79C6),
    cyan: Color(0xFF8BE9FD),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF6272A4),
    brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94),
    brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF),
    brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFF1FA8C),
    searchHitBackgroundCurrent: Color(0xFFFFB86C),
    searchHitForeground: Color(0xFF282A36),
  );

  static const _solarizedDark = TerminalTheme(
    cursor: Color(0xFF93A1A1),
    selection: Color(0x44073642),
    foreground: Color(0xFF839496),
    background: Color(0xFF002B36),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0xFFB58900),
    searchHitBackgroundCurrent: Color(0xFFCB4B16),
    searchHitForeground: Color(0xFF002B36),
  );

  static const _solarizedLight = TerminalTheme(
    cursor: Color(0xFF586E75),
    selection: Color(0x44EEE8D5),
    foreground: Color(0xFF657B83),
    background: Color(0xFFFDF6E3),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0xFFB58900),
    searchHitBackgroundCurrent: Color(0xFFCB4B16),
    searchHitForeground: Color(0xFFFDF6E3),
  );

  static const _gruvbox = TerminalTheme(
    cursor: Color(0xFFEBDBB2),
    selection: Color(0x44504945),
    foreground: Color(0xFFEBDBB2),
    background: Color(0xFF282828),
    black: Color(0xFF282828),
    red: Color(0xFFCC241D),
    green: Color(0xFF98971A),
    yellow: Color(0xFFD79921),
    blue: Color(0xFF458588),
    magenta: Color(0xFFB16286),
    cyan: Color(0xFF689D6A),
    white: Color(0xFFA89984),
    brightBlack: Color(0xFF928374),
    brightRed: Color(0xFFFB4934),
    brightGreen: Color(0xFFB8BB26),
    brightYellow: Color(0xFFFABD2F),
    brightBlue: Color(0xFF83A598),
    brightMagenta: Color(0xFFD3869B),
    brightCyan: Color(0xFF8EC07C),
    brightWhite: Color(0xFFEBDBB2),
    searchHitBackground: Color(0xFFFABD2F),
    searchHitBackgroundCurrent: Color(0xFFFE8019),
    searchHitForeground: Color(0xFF282828),
  );

  static const _nord = TerminalTheme(
    cursor: Color(0xFFD8DEE9),
    selection: Color(0x444C566A),
    foreground: Color(0xFFD8DEE9),
    background: Color(0xFF2E3440),
    black: Color(0xFF3B4252),
    red: Color(0xFFBF616A),
    green: Color(0xFFA3BE8C),
    yellow: Color(0xFFEBCB8B),
    blue: Color(0xFF81A1C1),
    magenta: Color(0xFFB48EAD),
    cyan: Color(0xFF88C0D0),
    white: Color(0xFFE5E9F0),
    brightBlack: Color(0xFF4C566A),
    brightRed: Color(0xFFBF616A),
    brightGreen: Color(0xFFA3BE8C),
    brightYellow: Color(0xFFEBCB8B),
    brightBlue: Color(0xFF81A1C1),
    brightMagenta: Color(0xFFB48EAD),
    brightCyan: Color(0xFF8FBCBB),
    brightWhite: Color(0xFFECEFF4),
    searchHitBackground: Color(0xFFEBCB8B),
    searchHitBackgroundCurrent: Color(0xFFD08770),
    searchHitForeground: Color(0xFF2E3440),
  );
}
