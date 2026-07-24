import 'package:flutter/material.dart';

/// Distinct accent colors assigned per open session (by tab order). The same
/// color marks a session's tab and its terminal header/border, so it is always
/// obvious which host the visible terminal belongs to — reducing the risk of
/// typing a command into the wrong tab.
const List<Color> kSessionPalette = [
  Color(0xFF26A69A), // teal
  Color(0xFFFB8C00), // orange
  Color(0xFFAB47BC), // purple
  Color(0xFF42A5F5), // blue
  Color(0xFFEC407A), // pink
  Color(0xFF66BB6A), // green
  Color(0xFF8D6E63), // brown
  Color(0xFF7E57C2), // deep purple
];

Color sessionAccent(int index) => kSessionPalette[index % kSessionPalette.length];
