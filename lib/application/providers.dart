import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/remote/host_sync_service.dart';
import '../data/remote/supabase_bootstrap.dart';
import '../data/repositories/drift_host_repository.dart';
import '../data/vault/secure_vault.dart';
import '../domain/entities/host.dart';
import '../domain/repositories/host_repository.dart';
import 'account_providers.dart';
import 'host_service.dart';

/// Singleton drift database for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// OS-backed secure storage for SSH secrets.
final secureVaultProvider = Provider<SecureVault>((ref) => SecureVault());

/// Host metadata repository.
final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => DriftHostRepository(ref.watch(databaseProvider)),
);

/// Live list of saved hosts, re-emitting on every change.
final hostsProvider = StreamProvider<List<Host>>(
  (ref) => ref.watch(hostRepositoryProvider).watchHosts(),
);

/// Coordinates host metadata with vault-stored secrets.
final hostServiceProvider = Provider<HostService>(
  (ref) => HostService(
    ref.watch(hostRepositoryProvider),
    ref.watch(secureVaultProvider),
  ),
);

/// Per-host share info (owned/shared-in/shared-out), rebuilt on each reconcile.
/// Drives the host-list labels. Empty until the first sync of a session.
class ShareInfoNotifier extends Notifier<Map<String, HostShareInfo>> {
  @override
  Map<String, HostShareInfo> build() => const {};

  void set(Map<String, HostShareInfo> value) => state = value;
}

final shareInfoProvider =
    NotifierProvider<ShareInfoNotifier, Map<String, HostShareInfo>>(
      ShareInfoNotifier.new,
    );

/// Share invitations addressed to me that I haven't accepted yet. Refreshed on
/// each reconcile; drives the invitation messages on the host list.
class InvitationsNotifier extends Notifier<List<HostInvitation>> {
  @override
  List<HostInvitation> build() => const [];

  void set(List<HostInvitation> value) => state = value;
}

final pendingInvitationsProvider =
    NotifierProvider<InvitationsNotifier, List<HostInvitation>>(
      InvitationsNotifier.new,
    );

/// The last sync outcome, so a failure is visible instead of silent. Null means
/// "not attempted yet".
class SyncStatus {
  const SyncStatus({this.error, this.undecryptableCount = 0});

  /// User-facing reason the last pass failed, or null when it succeeded.
  final String? error;

  /// Hosts the last pass could not decrypt (skipped, not lost).
  final int undecryptableCount;

  bool get isHealthy => error == null && undecryptableCount == 0;
}

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  void set(SyncStatus value) => state = value;
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

/// Keeps sync live: subscribes to realtime changes while signed in + unlocked,
/// refreshing local hosts and share labels on any event. Watch it from a
/// long-lived widget (the host list) to keep it alive.
final syncRealtimeProvider = Provider<void>((ref) {
  final sync = ref.watch(hostSyncServiceProvider);
  if (sync == null) return;

  // Realtime fires once per changed row, so a batch of edits would otherwise
  // start several overlapping reconciles — each writing to the local DB and
  // deciding independently which hosts need uploading, which can duplicate
  // work or collide. Run one at a time, and remember if another was requested
  // while one was in flight.
  var running = false;
  var pending = false;

  Future<void> refresh() async {
    if (running) {
      pending = true;
      return;
    }
    running = true;
    try {
      do {
        pending = false;
        try {
          final result = await sync.reconcile();
          ref.read(shareInfoProvider.notifier).set(result.shareInfo);
          ref
              .read(pendingInvitationsProvider.notifier)
              .set(await sync.pendingInvitations());
          ref.read(syncStatusProvider.notifier).set(
                SyncStatus(
                  undecryptableCount: result.undecryptableHostIds.length,
                ),
              );
        } catch (e) {
          // Offline is normal and transient, but a permanent failure used to be
          // indistinguishable from it — sync would simply stop working with no
          // sign at all. Record it so the UI can say so.
          ref.read(syncStatusProvider.notifier).set(SyncStatus(error: '$e'));
        }
      } while (pending);
    } finally {
      running = false;
    }
  }

  final channel = sync.subscribe(refresh);
  refresh();
  ref.onDispose(() => channel.unsubscribe());
});

/// End-to-end-encrypted host sync — non-null only when signed in and unlocked.
/// UI treats null as "cloud unavailable / not unlocked" and simply skips sync.
final hostSyncServiceProvider = Provider<HostSyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final account = ref.watch(accountControllerProvider).asData?.value;
  if (client == null || account is! AccountUnlocked) return null;
  return HostSyncService(
    client,
    ref.watch(hostServiceProvider),
    ref.watch(hostRepositoryProvider),
    account.identity,
  );
});

/// Distinct group names in use (always including the default group), sorted —
/// powers the group-field autocomplete when adding a host.
final groupsProvider = Provider<List<String>>((ref) {
  final hosts = ref.watch(hostsProvider).asData?.value ?? const [];
  final groups = <String>{kDefaultGroup};
  for (final h in hosts) {
    groups.add(displayGroup(h.groupName));
  }
  return groups.toList()..sort();
});
