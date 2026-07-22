/// Supabase connection configuration, injected at build time so no secrets are
/// committed. Provide them with `--dart-define`, e.g.:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
/// ```
///
/// The anon (publishable) key is safe to ship in the client — row-level
/// security on the server, plus end-to-end encryption of all sensitive data,
/// is what actually protects user data. When either value is empty the app
/// runs in fully local mode (no sign-in, no cloud sync) so builds without
/// credentials still work.
library;

class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether cloud features (accounts, sync, sharing) are available in this
  /// build. False when credentials were not supplied at build time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
