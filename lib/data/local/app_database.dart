import 'package:drift/drift.dart';

import 'db_connection.dart';

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
      : super(executor ?? openKerminalDatabase());

  @override
  int get schemaVersion => 1;

  /// Without a strategy, drift's default `onUpgrade` throws — so the first time
  /// [schemaVersion] is raised, every existing install would fail to open its
  /// database. Declared now, while there is nothing to migrate, so that adding a
  /// column later is a one-line change instead of a broken release.
  ///
  /// When bumping [schemaVersion], add a `from`/`to` branch here (e.g.
  /// `m.addColumn(hosts, hosts.newColumn)`) rather than relying on a rebuild.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // No migrations yet: v1 is the first schema.
        },
      );
}
