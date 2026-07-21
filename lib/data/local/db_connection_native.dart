import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _dbName = 'kerminal';

/// Opens the database in the app's private support directory, so it is removed
/// on uninstall (a fresh install starts empty) and is never synced to the
/// user's Documents/OneDrive.
QueryExecutor openKerminalDatabase() {
  return driftDatabase(
    name: _dbName,
    native: DriftNativeOptions(
      databaseDirectory: () async {
        final dir = await getApplicationSupportDirectory();
        await _migrateLegacyDatabase(dir);
        return dir;
      },
    ),
  );
}

/// One-time move of the pre-existing database from the Documents directory (the
/// old default location) into the app-private directory. The source is deleted
/// after moving, so uninstall + reinstall yields an empty app.
Future<void> _migrateLegacyDatabase(Directory targetDir) async {
  final target = File(p.join(targetDir.path, '$_dbName.sqlite'));
  if (await target.exists()) return; // already app-private; nothing to do
  try {
    final docs = await getApplicationDocumentsDirectory();
    await targetDir.create(recursive: true);
    for (final suffix in ['', '-wal', '-shm']) {
      final legacy = File(p.join(docs.path, '$_dbName.sqlite$suffix'));
      if (await legacy.exists()) {
        await legacy.copy('${target.path}$suffix');
        await legacy.delete();
      }
    }
  } catch (_) {
    // No legacy database (first run / unsupported platform) — ignore.
  }
}
