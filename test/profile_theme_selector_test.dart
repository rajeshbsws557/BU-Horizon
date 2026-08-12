import 'package:bu_horizon/bloc/theme_cubit.dart';
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/screens/profile_screen.dart';
import 'package:bu_horizon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [ProfileScreen] the same way the router does, minus Supabase.
Widget _harness() {
  return BlocProvider<ThemeCubit>(
    create: (_) => ThemeCubit(),
    child: BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) => MaterialApp(
        theme: AppTheme.lightOf(state.variant),
        darkTheme: AppTheme.darkOf(state.variant),
        themeMode: state.mode,
        home: const Scaffold(body: ProfileScreen()),
      ),
    ),
  );
}

void main() {
  setUpAll(configureDependencies);

  testWidgets('guest profile renders the theme selector', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The signed-out view must render at all (this is what regressed).
    expect(find.text('BU Horizon'), findsOneWidget);
    expect(find.text('Color Theme'), findsOneWidget);

    // All four palettes are offered. The active variant's name also appears in
    // the section subtitle, so match one-or-more rather than exactly one.
    for (final variant in AppThemeVariant.values) {
      expect(find.text(variant.label), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('tapping a palette switches the active variant', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppThemeVariant.matrixGreen.label));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Color Theme'));
    expect(
      context.colors.primary,
      AppThemeColors.matrixDark.primary,
    );
  });
}
