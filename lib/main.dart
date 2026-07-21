import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bloc/theme_cubit.dart';
import 'di/di.dart';
import 'navigation/app_router.dart';
import 'supabase/supabase_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The live project's credentials are baked in as defaults, so this runs for
  // every normal build. Blanking both values via --dart-define keeps the
  // UI-only design mode (sample data, no auth).
  if (SupabaseConfig.hasCredentials) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // The publishable (formerly "anon") key is safe to ship in a client;
      // RLS is what protects the data.
      publishableKey: SupabaseConfig.anonKey,
    );
    SupabaseConfig.markInitialized();
  }

  configureDependencies();
  runApp(const BUHorizonApp());
}

class BUHorizonApp extends StatelessWidget {
  const BUHorizonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>(
      create: (_) => ThemeCubit(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          final isLight = themeMode == ThemeMode.light;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isLight ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: isLight
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF05070E),
              systemNavigationBarIconBrightness:
                  isLight ? Brightness.dark : Brightness.light,
            ),
          );

          return MaterialApp.router(
            title: 'BU Horizon',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}

