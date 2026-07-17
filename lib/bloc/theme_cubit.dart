// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the application's [ThemeMode] seamlessly between
/// [ThemeMode.light] and [ThemeMode.dark].
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.dark);

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      emit(ThemeMode.light);
    } else {
      emit(ThemeMode.dark);
    }
  }

  void setThemeMode(ThemeMode mode) => emit(mode);

  bool get isLight => state == ThemeMode.light;
}
