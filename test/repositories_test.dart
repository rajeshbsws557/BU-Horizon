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

    test('returns all notices unmodifiable', () {
      expect(repo.notices, SampleData.notices);
      expect(() => repo.notices.clear(), throwsUnsupportedError);
    });

    test('filters by category', () {
      expect(
        repo.byCategory(NoticeCategory.academic).length,
        SampleData.notices.where((n) => n.category == NoticeCategory.academic).length,
      );
      expect(
        repo.byCategory(NoticeCategory.events).length,
        SampleData.notices.where((n) => n.category == NoticeCategory.events).length,
      );
      expect(
        repo.byCategory(NoticeCategory.department).length,
        SampleData.notices.where((n) => n.category == NoticeCategory.department).length,
      );
    });
  });

  group('SamplePeopleRepository', () {
    final repo = SamplePeopleRepository();

    test('returns all people when query is empty', () {
      expect(repo.search(''), SampleData.people);
    });

    test('searches by name', () {
      expect(repo.search('Rajib'), [SampleData.people[0]]);
    });

    test('searches by department', () {
      expect(repo.search('cse'), [SampleData.people[1]]);
    });

    test('searches by email', () {
      expect(repo.search('fahim.rahman'), [SampleData.people[3]]);
    });

    test('is case-insensitive and trims', () {
      expect(repo.search('  NUSRAT  '), [SampleData.people[1]]);
    });
  });

  group('SampleBloodRepository', () {
    final repo = SampleBloodRepository();

    test('returns urgent need', () {
      expect(repo.urgentNeed, SampleData.urgentBloodNeed);
    });

    test('returns requests unmodifiable', () {
      expect(repo.requests, SampleData.bloodRequests);
      expect(() => repo.requests.clear(), throwsUnsupportedError);
    });
  });

  group('SampleLostFoundRepository', () {
    final repo = SampleLostFoundRepository();

    test('splits lost and found items', () {
      expect(repo.lostItems.every((i) => i.isLost), isTrue);
      expect(repo.foundItems.every((i) => !i.isLost), isTrue);
      expect(repo.lostItems.length + repo.foundItems.length, SampleData.lostFound.length);
    });
  });

  group('SampleAttendanceRepository', () {
    final repo = SampleAttendanceRepository();

    test('returns today classes unmodifiable', () {
      expect(repo.todayClasses, SampleData.todayAttendance);
      expect(() => repo.todayClasses.clear(), throwsUnsupportedError);
    });

    test('summary computes present percentage', () {
      final summary = repo.summary();
      expect(summary.total, SampleData.todayAttendance.length);
      expect(summary.present, 3);
      expect(summary.percentage, closeTo(0.75, 0.001));
    });
  });

  group('SampleAlertRepository', () {
    final repo = SampleAlertRepository();

    test('partitions alerts correctly', () {
      final bus = repo.busAlerts();
      final notice = repo.noticeAlerts();
      final other = repo.otherAlerts();

      expect(bus.every((a) => a.type == AlertType.bus), isTrue);
      expect(
        notice.every((a) => a.type == AlertType.notice || a.type == AlertType.exam),
        isTrue,
      );
      expect(
        other.every(
          (a) =>
              a.type == AlertType.event ||
              a.type == AlertType.library ||
              a.type == AlertType.lostFound,
        ),
        isTrue,
      );
      expect(bus.length + notice.length + other.length, SampleData.alerts.length);
    });
  });
}
