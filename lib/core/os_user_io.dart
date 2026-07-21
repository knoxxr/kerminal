import 'dart:io';

/// Current OS user on native platforms (`USERNAME` on Windows, `USER` elsewhere).
String osUsername() =>
    Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? '';
