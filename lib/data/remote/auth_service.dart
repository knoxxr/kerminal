import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase email/password authentication.
///
/// Identity/session only — the account's encryption keys are handled separately
/// (see IdentityRepository / AccountController) so this layer never touches
/// plaintext secrets.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  /// Emits on sign-in, sign-out, token refresh, etc.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Creates an account. When email confirmation is enabled on the project the
  /// returned user has no active session until the email is confirmed; the
  /// caller should check [currentUser]/session accordingly.
  Future<User> signUp({required String email, required String password}) async {
    final res = await _auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) {
      throw const AuthException('Sign-up did not return a user.');
    }
    return user;
  }

  Future<User> signIn({required String email, required String password}) async {
    final res = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) {
      throw const AuthException('Sign-in did not return a user.');
    }
    return user;
  }

  Future<void> signOut() => _auth.signOut();
}
