import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/settings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Cloud (accounts/sync/sharing) is opt-in via --dart-define credentials;
  // in local-only builds this no-ops and the client provider stays null.
  final cloudReady = await initSupabase();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (cloudReady)
          supabaseClientProvider.overrideWithValue(Supabase.instance.client),
      ],
      child: const KerminalApp(),
    ),
  );
}

class KerminalApp extends ConsumerWidget {
  const KerminalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'Kerminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
