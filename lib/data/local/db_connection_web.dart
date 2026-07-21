import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// On the web, drift stores the database in IndexedDB (origin-private); there
/// is no Documents/OneDrive location to migrate from.
QueryExecutor openKerminalDatabase() => driftDatabase(name: 'kerminal');
