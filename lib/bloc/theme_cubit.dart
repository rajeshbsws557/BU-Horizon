// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_store.dart';
import '../di/di.dart';
import '../theme/app_theme.dart';

/// Combines [ThemeMode] (light/dark) with [AppThemeVariant] (the selected
/// cybersecurity palette).
class ThemeState {
  final ThemeMode mode;
  final AppThemeVariant variant;

  const ThemeState(this.mode, this.variant);

  ThemeState copyWith({ThemeMode? mode, AppThemeVariant? variant}) =>
      ThemeState(mode ?? this.mode, variant ?? this.variant);

  bool get isLight => mode == ThemeMode.light;
}

/// Cubit managing the application's theme: both brightness (light/dark) and
/// the selected cybersecurity palette variant.
///
/// Both choices are persisted through [LocalStore] so they survive restarts.
/// When persistence is unavailable (e.g. UI-only builds / tests) it simply
/// defaults to dark + cyber-blue and no-ops the save.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(_initialState());

  static ThemeState _initialState() {
    ThemeMode mode = ThemeMode.dark;
    AppThemeVariant variant = AppThemeVariant.fallback;

    if (getIt.isRegistered<LocalStore>()) {
      final store = getIt<LocalStore>();
      switch (store.themeMode) {
        case 'light':
          mode = ThemeMode.light;
          break;
        case 'dark':
          mode = ThemeMode.dark;
          break;
      }
      variant = AppThemeVariant.fromId(store.themeVariant);
    }
    return ThemeState(mode, variant);
  }

  void toggleTheme() => setThemeMode(
      state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  void setThemeMode(ThemeMode mode) {
    emit(state.copyWith(mode: mode));
    if (getIt.isRegistered<LocalStore>()) {
      getIt<LocalStore>()
          .setThemeMode(mode == ThemeMode.light ? 'light' : 'dark');
    }
  }

  void setVariant(AppThemeVariant variant) {
    emit(state.copyWith(variant: variant));
    if (getIt.isRegistered<LocalStore>()) {
      getIt<LocalStore>().setThemeVariant(variant.id);
    }
  }

  bool get isLight => state.isLight;
  ThemeMode get mode => state.mode;
  AppThemeVariant get variant => state.variant;
}
