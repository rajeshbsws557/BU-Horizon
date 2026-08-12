import 'package:bu_horizon/bloc/home_cards_cubit.dart';
import 'package:bu_horizon/data/home_cards.dart';
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The home screen now ships with exactly two cards (Class Notices + Bus
/// Schedule); everything else is opt-in through the customizer.
void main() {
  setUpAll(configureDependencies);

  group('HomeCardCatalog', () {
    test('defaults to Class Notices and Bus Schedule only', () {
      expect(HomeCardCatalog.defaultIds, ['notices', 'bus']);
      expect(HomeCardCatalog.defaultIds.length, 2);

      final cards = HomeCardCatalog.resolve(HomeCardCatalog.defaultIds);
      expect(cards.map((c) => c.title), ['Class Notices', 'Bus Schedule']);
    });

    test('resolve drops unknown ids and duplicates', () {
      final cards = HomeCardCatalog.resolve(['bus', 'bus', 'nope']);
      expect(cards.map((c) => c.id), ['bus']);
    });

    test('every catalog id is unique', () {
      final ids = HomeCardCatalog.all.map((c) => c.id).toSet();
      expect(ids.length, HomeCardCatalog.all.length);
    });
  });

  group('HomeCardsCubit', () {
    test('starts with the two default cards', () {
      final cubit = HomeCardsCubit();
      expect(cubit.pinnedIds, ['notices', 'bus']);
      addTearDown(cubit.close);
    });

    test('add pins a card at the end and remove takes it away', () {
      final cubit = HomeCardsCubit();
      addTearDown(cubit.close);

      cubit.add('exams');
      expect(cubit.pinnedIds, ['notices', 'bus', 'exams']);

      cubit.remove('bus');
      expect(cubit.pinnedIds, ['notices', 'exams']);
    });

    test('ignores unknown and duplicate ids', () {
      final cubit = HomeCardsCubit();
      addTearDown(cubit.close);

      cubit.add('does-not-exist');
      cubit.add('bus');
      expect(cubit.pinnedIds, ['notices', 'bus']);
    });

    test('honours the max-card ceiling', () {
      final cubit = HomeCardsCubit();
      addTearDown(cubit.close);

      for (final card in HomeCardCatalog.all) {
        cubit.add(card.id);
      }
      expect(cubit.state.length, HomeCardCatalog.maxCards);
      expect(cubit.isAtMax, isTrue);
    });

    test('reorder moves a card down using ReorderableListView indices', () {
      final cubit = HomeCardsCubit();
      addTearDown(cubit.close);

      cubit.add('exams');
      cubit.reorder(0, 3); // Class Notices to the end.
      expect(cubit.pinnedIds, ['bus', 'exams', 'notices']);
    });

    test('resetToDefaults restores the two starter cards', () {
      final cubit = HomeCardsCubit();
      addTearDown(cubit.close);

      cubit
        ..remove('bus')
        ..add('blood')
        ..resetToDefaults();
      expect(cubit.pinnedIds, ['notices', 'bus']);
    });

    test('availableCards excludes what is already pinned', () {
      final cubit = HomeCardsCubit();
      addTearDown(cubit.close);

      final availableIds = cubit.availableCards.map((c) => c.id);
      expect(availableIds, isNot(contains('bus')));
      expect(availableIds, contains('exams'));
    });
  });

  /// Advances a few frames. The phone layout shows the bottom nav, whose
  /// center hub pulses forever, so `pumpAndSettle` would never return.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Boots the app on a phone-sized surface (the default 800x600 test window
  /// counts as "wide", which swaps in the web top nav and duplicates labels).
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BUHorizonApp());
    await tester.pump();
    // Let the splash screen hand off to the home route.
    await tester.pump(const Duration(milliseconds: 3200));
    await settle(tester);
  }

  testWidgets('home screen renders only the two default cards',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Quick Access'), findsOneWidget);
    // Both defaults are present...
    expect(find.text('Class Notices'), findsOneWidget);
    expect(find.text('Bus Schedule'), findsOneWidget);
    // ...and the previously always-on cards are not.
    expect(find.text('Blood Help'), findsNothing);
    expect(find.text('Lost & Found'), findsNothing);
    expect(find.text('People Search'), findsNothing);
  });

  testWidgets('customizer opens and can add a card to the home screen',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Customize'));
    await settle(tester);

    expect(find.text('Customize Home'), findsOneWidget);

    // "Blood Help" sits in the "Add more cards" list, below the fold.
    await tester.dragUntilVisible(
      find.text('Blood Help'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await settle(tester);

    await tester.tap(find.text('Blood Help'));
    await settle(tester);

    // Dismiss the sheet by tapping the modal barrier, then confirm the card
    // landed on the home grid.
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    expect(find.text('Customize Home'), findsNothing);
    expect(find.text('Blood Help'), findsOneWidget);
  });

  testWidgets('removing a card takes it off the home screen',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Customize'));
    await settle(tester);

    await tester.tap(find.byTooltip('Remove Bus Schedule'));
    await settle(tester);

    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    expect(find.text('Class Notices'), findsOneWidget);
    expect(find.text('Bus Schedule'), findsNothing);
  });
}
