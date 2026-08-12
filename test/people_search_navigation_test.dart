import 'package:bu_horizon/navigation/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Regression tests for the People Search back button.
///
/// The bug: `/search` is a *top-level* route, but the home screen treated it
/// as a shell branch and navigated with `context.go()`. That replaced the
/// entire stack, so there was nothing to pop back to and Android's back
/// button quit the app instead of returning home.
void main() {
  testWidgets('pushing People Search keeps home underneath so back returns',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(AppRoutes.search),
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('People Search')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Open Search'), findsOneWidget);

    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();
    expect(find.text('People Search'), findsOneWidget);

    // The pushed page must sit on top of home, so a pop is possible. With the
    // old `context.go()` this stack was length 1 and canPop() was false — the
    // system back button then fell through to the OS and closed the app.
    final BuildContext searchContext =
        tester.element(find.text('People Search'));
    expect(searchContext.canPop(), isTrue);

    searchContext.pop();
    await tester.pumpAndSettle();
    expect(find.text('Open Search'), findsOneWidget);
    expect(find.text('People Search'), findsNothing);
  });

  test('membersOnly still gates People Search', () {
    // The routing fix must not accidentally open the members-only section up.
    expect(AppRoutes.membersOnly, contains(AppRoutes.search));
  });
}
