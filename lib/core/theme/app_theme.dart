import 'package:flutter/material.dart';

/// Central theme definitions. A terminal client is used in the dark most of
/// the time, so dark is the default; light is provided for completeness.
class AppTheme {
  static const _seed = Color(0xFF2E7D32);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
      );
}
