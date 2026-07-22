import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A colleague's shareable identity: the account id + public key needed to seal
/// host content keys to them.
class PublicIdentity {
  const PublicIdentity({
    required this.userId,
    required this.email,
    required this.publicKey,
  });

  final String userId;
  final String email;
  final Uint8List publicKey;
}

/// Reads/writes the cloud identity tables: `profiles` (public key, looked up by
/// others for sharing) and `account_keys` (the passphrase-wrapped private key,
/// owner-only via RLS). All values are stored encrypted/opaque.
class IdentityRepository {
  IdentityRepository(this._client);

  final SupabaseClient _client;

  /// Creates/updates the caller's public profile.
  Future<void> upsertProfile({
    required String userId,
    required String email,
    required Uint8List publicKey,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'email': email,
      'public_key': base64.encode(publicKey),
    });
  }

  /// Stores the caller's passphrase-wrapped private key.
  Future<void> saveWrappedPrivateKey(String userId, String wrapped) async {
    await _client.from('account_keys').upsert({
      'id': userId,
      'wrapped_private_key': wrapped,
    });
  }

  /// The caller's wrapped private key, or null if they haven't set one up yet.
  Future<String?> fetchWrappedPrivateKey(String userId) async {
    final row = await _client
        .from('account_keys')
        .select('wrapped_private_key')
        .eq('id', userId)
        .maybeSingle();
    return row?['wrapped_private_key'] as String?;
  }

  /// Looks up a colleague by email so their public key can be sealed to.
  /// Returns null when no such account exists.
  Future<PublicIdentity?> findByEmail(String email) async {
    final row = await _client
        .from('profiles')
        .select('id, email, public_key')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    if (row == null) return null;
    return PublicIdentity(
      userId: row['id'] as String,
      email: row['email'] as String,
      publicKey: base64.decode(row['public_key'] as String),
    );
  }
}
