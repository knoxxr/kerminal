import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads the user's OpenSSH client config, or null when there is none.
///
/// Desktop only — mobile apps are sandboxed and have no `~/.ssh` to read, and
/// the web build has no filesystem at all (see the stub).
Future<String?> readSshConfig() async {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '';
  if (home.isEmpty) return null;
  final file = File(p.join(home, '.ssh', 'config'));
  try {
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (_) {
    // Unreadable (permissions, a directory in its place) — treated the same as
    // absent so the caller can just say "nothing to import".
    return null;
  }
}

/// Whether importing is even possible here. Mobile has no accessible `~/.ssh`.
bool get sshConfigImportSupported =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;
