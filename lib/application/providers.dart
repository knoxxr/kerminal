import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/repositories/drift_host_repository.dart';
import '../data/vault/secure_vault.dart';
import '../domain/entities/host.dart';
import '../domain/repositories/host_repository.dart';

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
