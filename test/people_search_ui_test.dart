import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/models/models.dart';
import 'package:bu_horizon/repositories/people_repository.dart';
import 'package:bu_horizon/screens/people_search_screen.dart';
import 'package:bu_horizon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePeopleRepository implements PeopleRepository {
  static const _all = [
    Person(name: 'Nusrat Jahan', department: 'CSE Department', email: 'n@bu.edu.bd'),
    Person(name: 'Shakib Ahmed', department: 'EEE Department', email: 's@bu.edu.bd'),
    Person(name: 'Tania Islam', department: 'CSE Department', email: 't@bu.edu.bd'),
  ];

  @override
  Future<List<Person>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((p) => p.name.toLowerCase().contains(q)).toList();
  }
}

void main() {
  setUpAll(() {
    if (getIt.isRegistered<PeopleRepository>()) {
      getIt.unregister<PeopleRepository>();
    }
    getIt.registerFactory<PeopleRepository>(_FakePeopleRepository.new);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const PeopleSearchScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders a back button so the page can be dismissed',
      (tester) async {
    await pumpScreen(tester);
    expect(find.byType(AppBar), findsOneWidget);
    // BackButton is what the AppBar inserts automatically for a pushed route,
    // and it is what the old header-only layout was missing entirely.
    expect(find.text('People Search'), findsOneWidget);
  });

  testWidgets('shows every person and a live result count', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Nusrat Jahan'), findsOneWidget);
    expect(find.text('Shakib Ahmed'), findsOneWidget);
    expect(find.text('3 people found'), findsOneWidget);
  });

  testWidgets('typing filters the directory', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'nusrat');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Nusrat Jahan'), findsOneWidget);
    expect(find.text('Shakib Ahmed'), findsNothing);
    expect(find.text('1 person found'), findsOneWidget);
  });

  testWidgets('department chip narrows results and can be toggled off',
      (tester) async {
    await pumpScreen(tester);
    // Chips strip the trailing "Department" word for legibility.
    await tester.tap(find.text('EEE'));
    await tester.pumpAndSettle();

    expect(find.text('Shakib Ahmed'), findsOneWidget);
    expect(find.text('Nusrat Jahan'), findsNothing);
    expect(find.text('1 person found'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('3 people found'), findsOneWidget);
  });

  testWidgets('clear button resets the query', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'nusrat');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('1 person found'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('3 people found'), findsOneWidget);
  });

  testWidgets('empty search shows the friendly empty state', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No one found'), findsOneWidget);
    expect(find.text('0 people found'), findsOneWidget);
  });
}
