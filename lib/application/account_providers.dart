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

  /// Unlocks the identity with [passphrase]. If the account has no wrapped key
  /// yet (provisioned on another client), it is created now. Throws on a wrong
  /// passphrase.
  Future<void> unlock(String passphrase) async {
    final current = state.value;
    if (current is! AccountLocked) return;

    final wrapped = await _identity.fetchWrappedPrivateKey(current.userId);
    if (wrapped == null) {
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
      return;
    }

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

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncData(AccountSignedOut());
  }
}
