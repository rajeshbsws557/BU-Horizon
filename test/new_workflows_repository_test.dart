import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:bu_horizon/models/models.dart';
import 'package:bu_horizon/repositories/attendance_repository.dart';
import 'package:bu_horizon/repositories/blood_repository.dart';
import 'package:bu_horizon/repositories/bus_schedule_repository.dart';
import 'package:bu_horizon/repositories/notification_repository.dart';
import 'package:bu_horizon/services/bus_schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('static timetable paginates routes and persists favorites', () async {
    final repository = StaticBusScheduleRepository();
    final first = await repository.fetchPage(limit: 2);

    expect(
      first.categories.expand((category) => category.routes),
      hasLength(2),
    );
    expect(first.hasMore, isTrue);
    expect(first.source, BusScheduleSource.bundled);

    final route = first.categories.first.routes.first;
    await repository.setFavorite(route.id, true);
    expect(await repository.fetchFavoriteRouteIds(), contains(route.id));
    await repository.setFavorite(route.id, false);
    expect(await repository.fetchFavoriteRouteIds(), isNot(contains(route.id)));
  });

  test('sample attendance stores a pending correction request', () async {
    final repository = SampleAttendanceRepository();
    final sessions = await repository.fetchCourseSessions('offering-cse-1101');
    final session = sessions.first;

    await repository.requestCorrection(
      session: session,
      requestedStatus: AttendanceMark.absent,
      reason: 'The saved mark is incorrect.',
    );

    final refreshed = await repository.fetchCourseSessions('offering-cse-1101');
    expect(
      refreshed.firstWhere((item) => item.id == session.id).correctionStatus,
      'pending',
    );
    expect(
      refreshed
          .firstWhere((item) => item.id == session.id)
          .correctionRequestedAt,
      isNotNull,
    );
  });

  test('sample donor registration can be created and updated', () async {
    final repository = SampleBloodRepository();
    final registration = BloodDonorRegistration(
      group: BloodGroup.bPositive,
      contact: '01700000000',
      lastDonated: DateTime(2026, 1, 2),
      available: true,
    );

    await repository.saveDonorRegistration(registration);
    final saved = await repository.fetchMyDonorRegistration();

    expect(saved?.group, BloodGroup.bPositive);
    expect(saved?.contact, '01700000000');
    expect(saved?.available, isTrue);
  });

  test('sample notification repository has an empty read state', () async {
    final repository = SampleNotificationRepository();

    expect(await repository.unreadCount(), 0);
    expect((await repository.fetchPage()).items, isEmpty);
    await repository.markRead('missing');
    await repository.markAllRead();
  });

  test('bundled timetable remains available as offline source', () {
    expect(UniversityBusScheduleData.categories, isNotEmpty);
    expect(
      UniversityBusScheduleData.categories
          .expand((category) => category.routes)
          .expand((route) => route.departureSections)
          .expand((section) => section.trips),
      isNotEmpty,
    );
  });

  test('bundled timetable is not reported as a live sync', () async {
    final controller = BusScheduleController(StaticBusScheduleRepository());

    await controller.refresh();

    expect(controller.source, BusScheduleSource.bundled);
    expect(controller.lastSyncedAt, isNull);
  });
}
