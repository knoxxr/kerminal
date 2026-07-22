import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Initializes Supabase once at startup when credentials are configured.
/// Safe to call unconditionally: it no-ops in local-only builds.
///
/// Returns true when Supabase was initialized (cloud features available).
Future<bool> initSupabase() async {
  if (!SupabaseConfig.isConfigured) return false;
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // `publishableKey` is the current name for what older dashboards call the
    // "anon public" key; both values are accepted here.
    publishableKey: SupabaseConfig.anonKey,
  );
  return true;
}

/// The initialized [SupabaseClient], or null in local-only builds. Overridden
/// in [main] once [initSupabase] has run so widgets/services can depend on it
/// synchronously.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
