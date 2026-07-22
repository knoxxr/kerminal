import 'dart:typed_data';

/// An unlocked account: its cloud identity plus the in-memory key pair used to
/// encrypt/decrypt and to seal/open shared host content keys. The private key
/// lives only in memory while unlocked; it is never persisted in the clear.
class AccountIdentity {
  const AccountIdentity({
    required this.userId,
    required this.email,
    required this.publicKey,
    required this.privateKey,
  });

  final String userId;
  final String email;
  final Uint8List publicKey;
  final Uint8List privateKey;
}
