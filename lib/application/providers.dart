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
    if (h.groupName != null && h.groupName!.isNotEmpty) groups.add(h.groupName!);
  }
  return groups.toList()..sort();
});
