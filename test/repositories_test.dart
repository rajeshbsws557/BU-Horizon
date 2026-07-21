import 'package:bu_horizon/data/sample_data.dart';
import 'package:bu_horizon/models/models.dart';
import 'package:bu_horizon/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SampleBusRepository', () {
    late SampleBusRepository repo;

    setUp(() => repo = SampleBusRepository());

    test('returns all routes unmodifiable', () {
      expect(repo.routes.length, 5);
      expect(() => repo.routes.add(repo.routes.first), throwsUnsupportedError);
    });

    test('toggles favorite and emits updated routes', () {
      final first = repo.routes.first;
      final initial = first.favorite;
      repo.toggleFavorite(first.name);
      expect(repo.routes.first.favorite, !initial);
      repo.toggleFavorite(first.name);
      expect(repo.routes.first.favorite, initial);
    });

    test('ignores unknown route names', () {
      repo.toggleFavorite('Unknown Route');
      expect(repo.routes.length, 5);
    });

    test('favoriteRoutes filters favorites', () {
      expect(repo.favoriteRoutes.length, 2);
    });

    test('myRoutes returns first three routes', () {
      expect(repo.myRoutes.length, 3);
    });
  });

  group('SampleNoticeRepository', () {
    final repo = SampleNoticeRepository();

    test('returns all sample notices', () async {
      expect(await repo.fetchNotices(), SampleData.notices);
    });
  });

  group('SamplePeopleRepository', () {
    final repo = SamplePeopleRepository();

    test('returns all people when query is empty', () async {
      expect(await repo.search(''), SampleData.people);
    });

    test('searches by name', () async {
      expect(await repo.search('Rajib'), [SampleData.people[0]]);
    });

    test('searches by department', () async {
      expect(await repo.search('cse'), [SampleData.people[1]]);
    });

    test('searches by email', () async {
      expect(await repo.search('fahim.rahman'), [SampleData.people[3]]);
    });

    test('is case-insensitive and trims', () async {
      expect(await repo.search('  NUSRAT  '), [SampleData.people[1]]);
    });
  });

  group('SampleBloodRepository', () {
    final repo = SampleBloodRepository();

    test('returns sample requests', () async {
      expect(await repo.fetchRequests(), SampleData.bloodRequests);
    });

    test('writes require a backend', () {
      expect(
        () => repo.respond('any-id', contact: '000'),
        throwsStateError,
      );
    });
  });

  group('SampleLostFoundRepository', () {
    final repo = SampleLostFoundRepository();

    test('returns all sample items', () async {
      final items = await repo.fetchItems();
      expect(items, SampleData.lostFound);
      expect(items.where((i) => i.isLost).length +
          items.where((i) => !i.isLost).length, items.length);
    });

    test('writes require a backend', () {
      expect(
        () => repo.respond('any-id', contact: '000'),
        throwsStateError,
      );
    });
  });

  group('SampleAttendanceRepository', () {
    final repo = SampleAttendanceRepository();

    test('returns per-course summaries with sane percentages', () async {
      final courses = await repo.courseSummaries();
      expect(courses, isNotEmpty);
      for (final c in courses) {
        expect(c.present, lessThanOrEqualTo(c.total));
        expect(c.percentage, inInclusiveRange(0, 1));
      }
    });
  });

  group('SampleAlertRepository', () {
    final repo = SampleAlertRepository();

    test('returns all sample alerts', () async {
      final alerts = await repo.fetchAlerts();
      expect(alerts, SampleData.alerts);
      expect(alerts.map((a) => a.type).toSet(), AlertType.values.toSet());
    });
  });
}
