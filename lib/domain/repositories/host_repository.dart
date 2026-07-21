import '../entities/host.dart';

/// Persistence contract for [Host] metadata. Implemented in the data layer
/// (drift). Secrets are handled separately by the secure vault, never here.
abstract interface class HostRepository {
  /// Emits the full host list and re-emits on every change.
  Stream<List<Host>> watchHosts();

  Future<List<Host>> getHosts();

  Future<Host?> getHost(String id);

  Future<void> upsertHost(Host host);

  Future<void> deleteHost(String id);
}
