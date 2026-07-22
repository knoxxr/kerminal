import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/host_service.dart';
import '../../domain/entities/account_identity.dart';
import '../../domain/entities/host.dart';
import '../../domain/repositories/host_repository.dart';
import '../crypto/host_codec.dart';
import '../crypto/identity_crypto.dart';
import '../crypto/symmetric_crypto.dart';

/// End-to-end-encrypted sync of the signed-in user's own hosts.
///
/// A host's plaintext is encrypted with a fresh random content key on every
/// push; that content key is sealed to the owner's public key and stored in
/// `host_keys`. The server only ever holds ciphertext. The content key is never
/// persisted locally — it is re-derived by unsealing on pull. Requires an
/// unlocked [AccountIdentity].
class HostSyncService {
  HostSyncService(this._client, this._hosts, this._repo, this._identity);

  final SupabaseClient _client;
  final HostService _hosts;
  final HostRepository _repo;
  final AccountIdentity _identity;

  /// Encrypts and uploads a single host (create or update).
  Future<void> pushHost(Host host) async {
    final payload = await _hosts.readPayload(host);
    final contentKey = SymmetricCrypto.randomKey();
    final ciphertext = HostCodec.encrypt(payload, contentKey);

    await _client.from('hosts').upsert({
      'id': host.id,
      'owner_id': _identity.userId,
      'ciphertext': ciphertext,
      'deleted': false,
    });
    await _client.from('host_keys').upsert({
      'host_id': host.id,
      'recipient_id': _identity.userId,
      'sealed_content_key': base64.encode(
        IdentityCrypto.seal(contentKey, _identity.publicKey),
      ),
    });
  }

  /// Soft-deletes a host in the cloud (kept for history/rollback later).
  Future<void> pushDelete(String hostId) async {
    await _client.from('hosts').update({'deleted': true}).eq('id', hostId);
  }

  /// Pulls remote changes into local storage, then uploads any host that only
  /// exists locally. Run on unlock and on demand ("Sync now").
  Future<void> reconcile() async {
    final rows = await _client.from('hosts').select('id, ciphertext, deleted');
    final remoteIds = <String>{};

    for (final row in rows) {
      final id = row['id'] as String;
      remoteIds.add(id);
      if (row['deleted'] == true) {
        await _hosts.deleteLocalById(id);
        continue;
      }
      final keyRow = await _client
          .from('host_keys')
          .select('sealed_content_key')
          .eq('host_id', id)
          .eq('recipient_id', _identity.userId)
          .maybeSingle();
      if (keyRow == null) continue; // no key for us → cannot decrypt
      final contentKey = IdentityCrypto.unseal(
        base64.decode(keyRow['sealed_content_key'] as String),
        _identity.privateKey,
      );
      final payload = HostCodec.decrypt(row['ciphertext'] as String, contentKey);
      await _hosts.applyRemote(id, payload);
    }

    // Upload hosts that have never been synced (e.g. pre-existing local list).
    for (final host in await _repo.getHosts()) {
      if (!remoteIds.contains(host.id)) await pushHost(host);
    }
  }
}
