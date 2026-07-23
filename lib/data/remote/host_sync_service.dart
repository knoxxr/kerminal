import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/host_service.dart';
import '../../domain/entities/account_identity.dart';
import '../../domain/entities/host.dart';
import '../../domain/repositories/host_repository.dart';
import '../crypto/host_codec.dart';
import '../crypto/identity_crypto.dart';
import '../crypto/symmetric_crypto.dart';
import 'identity_repository.dart';

/// How a locally-visible host relates to the signed-in account: owned (and
/// possibly shared out) or shared in by a colleague. Drives the host-list
/// labels. Held in memory, rebuilt on each [HostSyncService.reconcile].
class HostShareInfo {
  const HostShareInfo({
    required this.ownedByMe,
    this.ownerEmail,
    this.sharedOut = false,
  });

  final bool ownedByMe;

  /// The owner's email when this host was shared *to* me.
  final String? ownerEmail;

  /// Whether I (the owner) have shared this host with anyone.
  final bool sharedOut;
}

/// One entry in a host's change history (see [HostSyncService.fetchHistory]).
class HostVersion {
  const HostVersion({
    required this.version,
    required this.op,
    required this.editorEmail,
    required this.createdAt,
    required this.hasSnapshot,
    this.summary,
  });

  final int version;

  /// 'create' | 'update' | 'delete' | 'rollback'.
  final String op;
  final String editorEmail;

  /// ISO-8601 timestamp string from the server.
  final String createdAt;

  /// Whether this version can be restored (has an encrypted snapshot).
  final bool hasSnapshot;

  /// Decrypted "label · host:port" at this version, if decryptable.
  final String? summary;
}

/// A soft-deleted host that can be restored (see [HostSyncService.fetchDeleted]).
class DeletedHost {
  const DeletedHost({required this.hostId, required this.summary});
  final String hostId;
  final String summary;
}

/// End-to-end-encrypted sync + sharing of hosts.
///
/// A host is encrypted with a stable per-host content key; that key is sealed
/// to the owner's public key and to each colleague it is shared with (one
/// `host_keys` row each). Sharing = sealing the same content key to a
/// colleague's public key. The content key is reused across edits so shares
/// survive updates, and is never persisted locally — it is recovered by
/// unsealing on demand. Requires an unlocked [AccountIdentity].
class HostSyncService {
  HostSyncService(this._client, this._hosts, this._repo, this._identity);

  final SupabaseClient _client;
  final HostService _hosts;
  final HostRepository _repo;
  final AccountIdentity _identity;

  // The id of the *live* signed-in user — exactly what the server sees as
  // auth.uid() for our requests. Used for owner_id / recipient_id and ownership
  // filters so the hosts RLS check `owner_id = auth.uid()` always matches, even
  // if the captured [AccountIdentity] ever drifts from the active session.
  String get _me => _client.auth.currentUser?.id ?? _identity.userId;

  /// Recovers a host's content key by unsealing the owner/recipient row that
  /// belongs to me, or null when I have no key row yet (host not synced).
  Future<Uint8List?> _contentKeyFor(String hostId) async {
    final row = await _client
        .from('host_keys')
        .select('sealed_content_key')
        .eq('host_id', hostId)
        .eq('recipient_id', _me)
        .maybeSingle();
    if (row == null) return null;
    return IdentityCrypto.unseal(
      base64.decode(row['sealed_content_key'] as String),
      _identity.privateKey,
    );
  }

  /// Encrypts and uploads a host I own (create or update). Reuses the existing
  /// content key when present so colleagues keep access after an edit, and
  /// records an applied version for history/rollback.
  Future<void> pushHost(Host host) async {
    final payload = await _hosts.readPayload(host);
    final existing = await _contentKeyFor(host.id);
    final contentKey = existing ?? SymmetricCrypto.randomKey();
    final ciphertext = HostCodec.encrypt(payload, contentKey);

    await _client.from('hosts').upsert({
      'id': host.id,
      'owner_id': _me,
      'ciphertext': ciphertext,
      'deleted': false,
    });
    await _client.from('host_keys').upsert({
      'host_id': host.id,
      'recipient_id': _me,
      'sealed_content_key': base64.encode(
        IdentityCrypto.seal(contentKey, _identity.publicKey),
      ),
    });
    await _recordVersion(host.id, existing == null ? 'create' : 'update', ciphertext);
  }

  Future<void> pushDelete(String hostId) async {
    await _client.from('hosts').update({'deleted': true}).eq('id', hostId);
    await _recordVersion(hostId, 'delete', null);
  }

  /// Appends an applied version snapshot for history/rollback.
  Future<void> _recordVersion(String hostId, String op, String? ciphertext) async {
    final maxRow = await _client
        .from('host_versions')
        .select('version')
        .eq('host_id', hostId)
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    final next = ((maxRow?['version'] as int?) ?? 0) + 1;
    await _client.from('host_versions').insert({
      'host_id': hostId,
      'version': next,
      'editor_id': _me,
      'op': op,
      'ciphertext': ciphertext,
      'status': 'applied',
    });
  }

  /// Shares a host I own with [colleague] by sealing its content key to their
  /// public key. Throws if the host hasn't been synced yet.
  Future<void> shareHost(String hostId, PublicIdentity colleague) async {
    final contentKey = await _contentKeyFor(hostId);
    if (contentKey == null) {
      throw StateError('Host is not synced yet — sync it first.');
    }
    await _client.from('host_keys').upsert({
      'host_id': hostId,
      'recipient_id': colleague.userId,
      'sealed_content_key': base64.encode(
        IdentityCrypto.seal(contentKey, colleague.publicKey),
      ),
      'can_edit': true,
    });
  }

  Future<void> unshareHost(String hostId, String recipientId) async {
    await _client
        .from('host_keys')
        .delete()
        .eq('host_id', hostId)
        .eq('recipient_id', recipientId);
  }

  /// The colleagues a host is currently shared with (excludes me).
  Future<List<PublicIdentity>> recipientsOf(String hostId) async {
    final rows = await _client
        .from('host_keys')
        .select('recipient_id')
        .eq('host_id', hostId)
        .neq('recipient_id', _me);
    final ids = rows.map((r) => r['recipient_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final profs = await _client
        .from('profiles')
        .select('id, email, public_key')
        .inFilter('id', ids);
    return profs
        .map(
          (p) => PublicIdentity(
            userId: p['id'] as String,
            email: p['email'] as String,
            publicKey: base64.decode(p['public_key'] as String),
          ),
        )
        .toList();
  }

  /// Pulls remote changes into local storage, uploads any local-only host, and
  /// returns per-host share info for the UI labels.
  Future<Map<String, HostShareInfo>> reconcile() async {
    final hostRows = await _client
        .from('hosts')
        .select('id, owner_id, ciphertext, deleted');
    final keyRows = await _client
        .from('host_keys')
        .select('host_id, recipient_id, sealed_content_key');

    // My sealed key per host, and which hosts I've shared out.
    final myKey = <String, String>{};
    final sharedOut = <String>{};
    for (final k in keyRows) {
      final hostId = k['host_id'] as String;
      final recipient = k['recipient_id'] as String;
      if (recipient == _me) {
        myKey[hostId] = k['sealed_content_key'] as String;
      } else {
        // RLS only returns non-me rows for hosts I own → those are shared out.
        sharedOut.add(hostId);
      }
    }

    // Resolve owner emails for hosts shared to me.
    final foreignOwnerIds = <String>{
      for (final r in hostRows)
        if (r['owner_id'] as String != _me) r['owner_id'] as String,
    };
    final ownerEmail = <String, String>{};
    if (foreignOwnerIds.isNotEmpty) {
      final profs = await _client
          .from('profiles')
          .select('id, email')
          .inFilter('id', foreignOwnerIds.toList());
      for (final p in profs) {
        ownerEmail[p['id'] as String] = p['email'] as String;
      }
    }

    final info = <String, HostShareInfo>{};
    final remoteIds = <String>{};

    for (final row in hostRows) {
      final id = row['id'] as String;
      final ownerId = row['owner_id'] as String;
      remoteIds.add(id);

      if (row['deleted'] == true) {
        await _hosts.deleteLocalById(id);
        continue;
      }
      final sealed = myKey[id];
      if (sealed == null) continue; // no key for us → cannot decrypt

      final contentKey = IdentityCrypto.unseal(
        base64.decode(sealed),
        _identity.privateKey,
      );
      final payload = HostCodec.decrypt(row['ciphertext'] as String, contentKey);
      await _hosts.applyRemote(id, payload);

      final ownedByMe = ownerId == _me;
      info[id] = HostShareInfo(
        ownedByMe: ownedByMe,
        ownerEmail: ownedByMe ? null : ownerEmail[ownerId],
        sharedOut: ownedByMe && sharedOut.contains(id),
      );
    }

    // Upload hosts that have never been synced (e.g. a pre-existing local list).
    for (final host in await _repo.getHosts()) {
      if (!remoteIds.contains(host.id)) {
        await pushHost(host);
        info[host.id] = const HostShareInfo(ownedByMe: true);
      }
    }

    return info;
  }

  // --- History & rollback (P5) ---

  /// The change history of a host (newest first), for display and rollback.
  Future<List<HostVersion>> fetchHistory(String hostId) async {
    final contentKey = await _contentKeyFor(hostId);
    final rows = await _client
        .from('host_versions')
        .select('version, op, editor_id, ciphertext, created_at')
        .eq('host_id', hostId)
        .order('version', ascending: false);
    if (rows.isEmpty) return const [];

    final editorIds = {for (final r in rows) r['editor_id'] as String};
    final profs = await _client
        .from('profiles')
        .select('id, email')
        .inFilter('id', editorIds.toList());
    final email = {for (final p in profs) p['id'] as String: p['email'] as String};

    return [
      for (final r in rows)
        HostVersion(
          version: r['version'] as int,
          op: r['op'] as String,
          editorEmail: email[r['editor_id'] as String] ?? '',
          createdAt: r['created_at'] as String? ?? '',
          hasSnapshot: r['ciphertext'] != null,
          summary: _summaryOf(r['ciphertext'] as String?, contentKey),
        ),
    ];
  }

  String? _summaryOf(String? ciphertext, Uint8List? key) {
    if (ciphertext == null || key == null) return null;
    try {
      final p = HostCodec.decrypt(ciphertext, key);
      return '${p.label} · ${p.hostname}:${p.port}';
    } catch (_) {
      return null;
    }
  }

  /// Restores a host to the snapshot at [version], recording a new version.
  Future<void> rollbackTo(String hostId, int version) async {
    final row = await _client
        .from('host_versions')
        .select('ciphertext')
        .eq('host_id', hostId)
        .eq('version', version)
        .maybeSingle();
    final ciphertext = row?['ciphertext'] as String?;
    if (ciphertext == null) {
      throw StateError('That version has no snapshot to restore.');
    }
    await _client
        .from('hosts')
        .update({'ciphertext': ciphertext, 'deleted': false})
        .eq('id', hostId);
    await _recordVersion(hostId, 'rollback', ciphertext);
    final contentKey = await _contentKeyFor(hostId);
    if (contentKey != null) {
      await _hosts.applyRemote(hostId, HostCodec.decrypt(ciphertext, contentKey));
    }
  }

  /// Soft-deleted hosts I own — the "trash" that can be restored.
  Future<List<DeletedHost>> fetchDeleted() async {
    final rows = await _client
        .from('hosts')
        .select('id, ciphertext')
        .eq('owner_id', _me)
        .eq('deleted', true);
    final result = <DeletedHost>[];
    for (final r in rows) {
      final id = r['id'] as String;
      final contentKey = await _contentKeyFor(id);
      final summary =
          _summaryOf(r['ciphertext'] as String?, contentKey) ?? '(host)';
      result.add(DeletedHost(hostId: id, summary: summary));
    }
    return result;
  }

  /// Un-deletes a host and re-adds it locally.
  Future<void> restoreDeleted(String hostId) async {
    await _client.from('hosts').update({'deleted': false}).eq('id', hostId);
    final row = await _client
        .from('hosts')
        .select('ciphertext')
        .eq('id', hostId)
        .maybeSingle();
    final ciphertext = row?['ciphertext'] as String?;
    await _recordVersion(hostId, 'rollback', ciphertext);
    final contentKey = await _contentKeyFor(hostId);
    if (contentKey != null && ciphertext != null) {
      await _hosts.applyRemote(hostId, HostCodec.decrypt(ciphertext, contentKey));
    }
  }

  // --- Realtime ---

  /// Subscribes to host/sharing changes; [onChange] fires on any relevant event
  /// (another of my devices, or a host newly shared with me). Caller must
  /// unsubscribe.
  RealtimeChannel subscribe(void Function() onChange) {
    final channel = _client.channel('kerminal-sync');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hosts',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'host_keys',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }
}
