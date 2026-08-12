import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bloc/home_cards_cubit.dart';
import 'bloc/theme_cubit.dart';
import 'data/local_store.dart';
import 'di/di.dart';
import 'navigation/app_router.dart';
import 'services/bus_alarm_service.dart';
import 'supabase/supabase_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On-device persistence (settings + offline cache). Registered before the
  // rest of DI so ThemeCubit can restore the saved theme on first frame.
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<LocalStore>(LocalStore(prefs));

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

  // Create the alarm notification channel and re-arm any bus alarm the OS
  // dropped (app update / force stop / reboot). Deliberately not awaited so a
  // slow platform channel can never delay first frame; failures are logged
  // inside the service rather than blocking startup.
  unawaited(BusAlarmService.instance.restorePendingAlarms());

  runApp(const BUHorizonApp());
}

class BUHorizonApp extends StatelessWidget {
  const BUHorizonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        // Owns the home-screen card layout; provided above MaterialApp so the
        // customizer bottom sheet (a separate route) can reach it too.
        BlocProvider<HomeCardsCubit>(create: (_) => HomeCardsCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          final isLight = themeState.isLight;
          // Tint the system bars with the *selected* palette so the chrome
          // matches the app instead of a hard-coded navy.
          final palette = themeState.variant
              .palette(isLight ? Brightness.light : Brightness.dark);
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isLight ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: palette.background,
              systemNavigationBarIconBrightness:
                  isLight ? Brightness.dark : Brightness.light,
            ),
          );

          return MaterialApp.router(
            title: 'BU Horizon',
            debugShowCheckedModeBanner: false,
            themeMode: themeState.mode,
            theme: AppTheme.lightOf(themeState.variant),
            darkTheme: AppTheme.darkOf(themeState.variant),
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}

