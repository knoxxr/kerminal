import 'package:drift/drift.dart';

import '../../domain/entities/host.dart';
import '../../domain/repositories/host_repository.dart';
import '../local/app_database.dart';

/// [HostRepository] backed by the drift [AppDatabase].
class DriftHostRepository implements HostRepository {
  DriftHostRepository(this._db);

  final AppDatabase _db;

  Host _toEntity(HostRow row) => Host(
        id: row.id,
        label: row.label,
        hostname: row.hostname,
        port: row.port,
        username: row.username,
        authMethod: AuthMethod.values[row.authMethod],
        groupName: row.groupName,
        credentialId: row.credentialId,
      );

  HostsCompanion _toCompanion(Host host) => HostsCompanion(
        id: Value(host.id),
        label: Value(host.label),
        hostname: Value(host.hostname),
        port: Value(host.port),
        username: Value(host.username),
        authMethod: Value(host.authMethod.index),
        groupName: Value(host.groupName),
        credentialId: Value(host.credentialId),
      );

  @override
  Stream<List<Host>> watchHosts() =>
      _db.select(_db.hosts).watch().map((rows) => rows.map(_toEntity).toList());

  @override
  Future<List<Host>> getHosts() async {
    final rows = await _db.select(_db.hosts).get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Host?> getHost(String id) async {
    final row = await (_db.select(_db.hosts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> upsertHost(Host host) =>
      _db.into(_db.hosts).insertOnConflictUpdate(_toCompanion(host));

  @override
  Future<void> deleteHost(String id) =>
      (_db.delete(_db.hosts)..where((t) => t.id.equals(id))).go();
}
