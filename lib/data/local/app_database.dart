import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Host metadata table. Secrets (passwords, private keys) are NOT stored here;
/// they live in the secure vault and are referenced by [credentialId].
///
/// The generated row class is named `HostRow` to avoid clashing with the
/// domain-layer `Host` entity.
@DataClassName('HostRow')
class Hosts extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get hostname => text()();
  IntColumn get port => integer().withDefault(const Constant(22))();
  TextColumn get username => text()();

  /// Stored as the enum index of [AuthMethod].
  IntColumn get authMethod => integer().withDefault(const Constant(0))();
  TextColumn get groupName => text().nullable()();
  TextColumn get credentialId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Hosts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'kominal');
  }
}
