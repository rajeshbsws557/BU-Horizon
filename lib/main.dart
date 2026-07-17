import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/theme_cubit.dart';
import 'di/di.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

