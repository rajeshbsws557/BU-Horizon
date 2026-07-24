// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_store.dart';
import '../di/di.dart';

/// Cubit managing the application's [ThemeMode] between light and dark.
///
/// The chosen mode is persisted through [LocalStore] so it survives restarts.
/// When persistence is unavailable (e.g. UI-only builds / tests) it simply
/// defaults to dark and no-ops the save.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(_initialMode());

  static ThemeMode _initialMode() {
    if (getIt.isRegistered<LocalStore>()) {
      switch (getIt<LocalStore>().themeMode) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
      }
    }
    return ThemeMode.dark;
  }

  void toggleTheme() =>
      setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  void setThemeMode(ThemeMode mode) {
    emit(mode);
    if (getIt.isRegistered<LocalStore>()) {
      getIt<LocalStore>().setThemeMode(mode == ThemeMode.light ? 'light' : 'dark');
    }
  }

  bool get isLight => state == ThemeMode.light;
}
