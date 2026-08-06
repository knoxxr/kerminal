import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crypto/identity_crypto.dart';
import '../data/remote/auth_service.dart';
import '../data/remote/identity_repository.dart';
import '../data/remote/supabase_bootstrap.dart';
import '../domain/entities/account_identity.dart';

/// Account/sync availability and, once unlocked, the in-memory identity.
sealed class AccountState {
  const AccountState();
}

/// This build has no Supabase credentials — cloud features are unavailable.
class AccountCloudDisabled extends AccountState {
  const AccountCloudDisabled();
}

/// Cloud is available but no user is signed in.
class AccountSignedOut extends AccountState {
  const AccountSignedOut();
}

/// Signed in, but the encryption key hasn't been unlocked with the passphrase.
class AccountLocked extends AccountState {
  const AccountLocked({required this.userId, required this.email});
  final String userId;
  final String email;
}

/// Signed in and unlocked; [identity] holds the in-memory key pair.
class AccountUnlocked extends AccountState {
  const AccountUnlocked(this.identity);
  final AccountIdentity identity;
}

/// A user-facing account error (kept separate from crypto exceptions).
class AccountException implements Exception {
  const AccountException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// This account has no encryption key stored yet, so there is nothing a
/// passphrase could unlock. Distinct from a wrong passphrase: the answer is to
/// set one up ([AccountController.createEncryptionKey]), which the UI must warn
/// about because it invalidates anything encrypted for a previous key.
class MissingEncryptionKeyException implements Exception {
  const MissingEncryptionKeyException();
  @override
  String toString() => 'This account has no encryption key yet.';
}

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AuthService(client);
});

final identityRepositoryProvider = Provider<IdentityRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : IdentityRepository(client);
});

final accountControllerProvider =
    AsyncNotifierProvider<AccountController, AccountState>(AccountController.new);

/// Drives sign-up / sign-in / unlock / sign-out and holds the resulting state.
///
/// Mutating methods throw [AccountException] (or a crypto exception for a wrong
/// passphrase) on failure so the UI can show a transient message while the
/// current state is preserved; state only advances on success.
class AccountController extends AsyncNotifier<AccountState> {
  AuthService get _auth => ref.read(authServiceProvider)!;
  IdentityRepository get _identity => ref.read(identityRepositoryProvider)!;

  @override
  Future<AccountState> build() async {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return const AccountCloudDisabled();
    final user = client.auth.currentUser;
    if (user == null) return const AccountSignedOut();
    return AccountLocked(userId: user.id, email: user.email ?? '');
  }

  /// Creates an account, generates its key pair, and unlocks it. Requires email
  /// confirmation to be disabled (otherwise there is no session yet — the user
  /// is told to confirm and sign in).
  Future<void> signUp({
    required String email,
    required String password,
    required String passphrase,
  }) async {
    final user = await _auth.signUp(email: email, password: password);
    if (_auth.currentUser == null) {
      state = const AsyncData(AccountSignedOut());
      throw const AccountException(
        'Account created. Confirm your email, then sign in.',
      );
    }
    final kp = IdentityCrypto.generate();
    await _identity.upsertProfile(
      userId: user.id,
      email: email,
      publicKey: kp.publicKey,
    );
    await _identity.saveWrappedPrivateKey(
      user.id,
      IdentityCrypto.wrapPrivateKey(kp.privateKey, passphrase),
    );
    state = AsyncData(
      AccountUnlocked(
        AccountIdentity(
          userId: user.id,
          email: email,
          publicKey: kp.publicKey,
          privateKey: kp.privateKey,
        ),
      ),
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _auth.signIn(email: email, password: password);
    state = AsyncData(
      AccountLocked(userId: user.id, email: user.email ?? email),
    );
  }

  /// Unlocks the identity with [passphrase]. Throws on a wrong passphrase, and
  /// [MissingEncryptionKeyException] when this account has no encryption key
  /// yet — see [createEncryptionKey].
  Future<void> unlock(String passphrase) async {
    final current = state.value;
    if (current is! AccountLocked) return;

    final wrapped = await _identity.fetchWrappedPrivateKey(current.userId);
    // Generating a key here would accept *any* passphrase and overwrite the
    // account's public key, permanently locking the user out of everything
    // already synced or shared with them. Make it an explicit, warned-about
    // choice instead.
    if (wrapped == null) throw const MissingEncryptionKeyException();

    final privateKey = IdentityCrypto.unwrapPrivateKey(wrapped, passphrase);
    state = AsyncData(
      AccountUnlocked(
        AccountIdentity(
          userId: current.userId,
          email: current.email,
          publicKey: IdentityCrypto.publicKeyOf(privateKey),
          privateKey: privateKey,
        ),
      ),
    );
  }

  /// Sets up this account's encryption key for the first time, wrapping it with
  /// [passphrase].
  ///
  /// Only valid when the account genuinely has no key (a fresh account, or one
  /// created before sync existed). It replaces the account's public key, so any
  /// host previously encrypted for the old key — including hosts colleagues
  /// shared — becomes unreadable. The UI must warn before calling this.
  Future<void> createEncryptionKey(String passphrase) async {
    final current = state.value;
    if (current is! AccountLocked) return;

    final kp = IdentityCrypto.generate();
    await _identity.upsertProfile(
      userId: current.userId,
      email: current.email,
      publicKey: kp.publicKey,
    );
    await _identity.saveWrappedPrivateKey(
      current.userId,
      IdentityCrypto.wrapPrivateKey(kp.privateKey, passphrase),
    );
    state = AsyncData(
      AccountUnlocked(
        AccountIdentity(
          userId: current.userId,
          email: current.email,
          publicKey: kp.publicKey,
          privateKey: kp.privateKey,
        ),
      ),
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncData(AccountSignedOut());
  }
}
