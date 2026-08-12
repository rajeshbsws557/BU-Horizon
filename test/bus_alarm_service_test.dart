// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Guards for the "the alarm never goes off" bug.
//
// The parts that can be verified without a real device are pinned here:
//  * notification ids must be STABLE across runs, otherwise "Cancel Alarm"
//    targets an id the OS never knew about and the alarm keeps ringing;
//  * the alarm channel must be configured for the device ringtone on the alarm
//    audio stream, since a channel created silently on Android 8+ can never be
//    made audible afterwards;
//  * persistence round-trips must keep the id so cancellation survives a
//    restart.
// Actual ringing is an OS behaviour and is covered by the manual device
// checklist, not by these tests.
import 'package:bu_horizon/services/bus_alarm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('notification ids', () {
    test('are deterministic for the same trip', () {
      final service = BusAlarmService.instance;
      const tripId = 'student_route_01__বিশ্ববিদ্যালয়__8:30 AM';

      // Recomputed on every app launch — if this were `String.hashCode` the
      // value could differ between processes and cancelling would silently
      // miss the scheduled alarm.
      expect(service.notificationIdFor(tripId),
          service.notificationIdFor(tripId));
    });

    test('differ between trips so alarms never overwrite each other', () {
      final service = BusAlarmService.instance;

      final morning =
          service.notificationIdFor('student_route_01__বিশ্ববিদ্যালয়__8:30 AM');
      final evening =
          service.notificationIdFor('student_route_01__বিশ্ববিদ্যালয়__9:00 PM');
      final otherRoute =
          service.notificationIdFor('student_route_02__বিশ্ববিদ্যালয়__8:30 AM');

      expect({morning, evening, otherRoute}.length, 3);
    });

    test('stay inside the positive 32-bit range Android accepts', () {
      final service = BusAlarmService.instance;

      for (final id in [
        'a',
        'student_route_03__নথুল্লাবাদ__10:00 PM',
        'x' * 200,
      ]) {
        final value = service.notificationIdFor(id);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });

  group('alarm sound configuration', () {
    test('channel id is versioned away from every previously shipped id', () {
      // Android freezes a channel's sound at creation time, so reusing an old
      // id would keep every upgraded user's alarm permanently muted. v1 was
      // soundless; v2 had the unplayable settings-alias URI.
      expect(kBusAlarmChannelId, isNot('bu_horizon_bus_alarms'));
      expect(kBusAlarmChannelId, isNot('bu_horizon_bus_alarms_v2'));
    });

    test('resolves a sound URI from the platform rather than the alias', () {
      // `content://settings/system/ringtone` is a RingtoneManager indirection,
      // not playable media. Handing it to setSound() is what left the alarm
      // vibrating in silence, so it must never be the value we resolve to.
      expect(
        BusAlarmService.instance.resolveAlarmSoundUri(),
        completion(isNot(kDeviceRingtoneUri)),
      );
    });

    test('degrades to the platform default when nothing resolves', () async {
      // No MainActivity on the test host: must report null (-> plugin default,
      // still audible) rather than throwing or returning a dead URI.
      expect(await BusAlarmService.instance.resolveAlarmSoundUri(), isNull);
    });
  });

  group('notification icon', () {
    test('is a dedicated monochrome drawable, not the launcher icon', () {
      // Android alpha-masks small icons and discards colour, so the opaque
      // square of '@mipmap/ic_launcher' rendered as a featureless grey block.
      expect(kNotificationIcon, 'ic_stat_bus_alarm');
      expect(kNotificationIcon, isNot(contains('mipmap')));
      expect(kNotificationIcon, isNot(contains('ic_launcher')));
    });
  });

  group('persistence', () {
    test('round-trips the notification id so cancel can find the alarm', () {
      final alarm = ScheduledBusAlarmInfo(
        id: 'student_route_01__বিশ্ববিদ্যালয়__8:30 AM',
        routeName: 'Route 01',
        departurePlace: 'বিশ্ববিদ্যালয়',
        tripTime: '8:30 AM',
        busName: 'বৈকালি',
        leadMinutes: 15,
        scheduledRingTimeIso: '2026-08-06T08:15:00.000',
        notificationId: 12345,
      );

      final restored = ScheduledBusAlarmInfo.fromJson(alarm.toJson());

      expect(restored.id, alarm.id);
      expect(restored.notificationId, 12345);
      expect(restored.leadMinutes, 15);
      expect(restored.scheduledRingTime, DateTime(2026, 8, 6, 8, 15));
    });

    test('tolerates alarms saved before ids were persisted', () {
      // Users upgrading from the previous build have stored alarms with no
      // `notificationId`; reading those must not throw.
      final legacy = ScheduledBusAlarmInfo.fromJson({
        'id': 'student_route_01__বিশ্ববিদ্যালয়__8:30 AM',
        'routeName': 'Route 01',
        'departurePlace': 'বিশ্ববিদ্যালয়',
        'tripTime': '8:30 AM',
        'busName': 'বৈকালি',
        'leadMinutes': 15,
        'scheduledRingTimeIso': '2026-08-06T08:15:00.000',
      });

      expect(legacy.notificationId, isNull);
    });

    test('stores, finds and removes an alarm by trip id', () async {
      final service = BusAlarmService.instance;
      const tripId = 'student_route_01__বিশ্ববিদ্যালয়__8:30 AM';

      expect(await service.getAlarmForTrip(tripId), isNull);

      // The plugin has no implementation in the test host, so scheduling
      // degrades to bookkeeping only — which is exactly the layer under test.
      await service.scheduleBusAlarm(
        tripId: tripId,
        routeName: 'Route 01',
        departurePlace: 'বিশ্ববিদ্যালয়',
        tripTime: '8:30 AM',
        busName: 'বৈকালি',
        leadMinutes: 15,
      );

      final stored = await service.getAlarmForTrip(tripId);
      expect(stored, isNotNull);
      expect(stored!.leadMinutes, 15);
      // The id it was scheduled under is persisted, so a later cancel (even
      // after a restart) targets the right pending alarm.
      expect(stored.notificationId, service.notificationIdFor(tripId));
      // The alarm is armed for a moment that is still ahead of us.
      expect(stored.scheduledRingTime.isAfter(DateTime.now()), isTrue);

      await service.cancelBusAlarm(tripId);
      expect(await service.getAlarmForTrip(tripId), isNull);
    });

    test('re-setting an alarm updates it instead of duplicating', () async {
      final service = BusAlarmService.instance;
      const tripId = 'student_route_02__রূপাতলী__10:15 AM';

      await service.scheduleBusAlarm(
        tripId: tripId,
        routeName: 'Route 02',
        departurePlace: 'রূপাতলী',
        tripTime: '10:15 AM',
        busName: 'সুগন্ধা',
        leadMinutes: 10,
      );
      await service.scheduleBusAlarm(
        tripId: tripId,
        routeName: 'Route 02',
        departurePlace: 'রূপাতলী',
        tripTime: '10:15 AM',
        busName: 'সুগন্ধা',
        leadMinutes: 30,
      );

      final all = await service.getScheduledAlarms();
      expect(all.where((a) => a.id == tripId).length, 1);
      expect(all.single.leadMinutes, 30);

      await service.cancelBusAlarm(tripId);
    });
  });

  group('permissions never block scheduling', () {
    // THE REGRESSION THIS PINS
    // A previous build threw "enable the permission in Settings" whenever the
    // notification switch read false. On Android 12 and below there is no such
    // permission entry to enable (POST_NOTIFICATIONS only exists on 13+), so
    // the alarm became impossible to set and the instructions pointed at a
    // screen that doesn't exist. Scheduling must always go through.
    test('an alarm is still created when permissions look unavailable',
        () async {
      final service = BusAlarmService.instance;
      const tripId = 'student_route_01__বিশ্ববিদ্যালয়__9:30 AM';

      // No plugin on the test host, so every permission probe throws
      // MissingPluginException — the harshest "can't tell" case there is.
      final alarm = await service.scheduleBusAlarm(
        tripId: tripId,
        routeName: 'Route 01',
        departurePlace: 'বিশ্ববিদ্যালয়',
        tripTime: '9:30 AM',
        busName: 'চিত্রা',
        leadMinutes: 15,
      );

      expect(alarm.id, tripId);
      expect(await service.getAlarmForTrip(tripId), isNotNull);

      await service.cancelBusAlarm(tripId);
    });

    test('unknown permission state reads as allowed, not denied', () async {
      // Optimistic by design: a wrong "granted" only means we still try, while
      // a wrong "denied" is what broke the feature outright.
      final status = await BusAlarmService.instance.ensurePermissions();

      expect(status.notificationsGranted, isTrue);
      expect(status.exactAlarmsGranted, isTrue);
    });

    test('opening settings degrades quietly when unavailable', () async {
      // No MainActivity on the test host: must report false, never throw, so
      // the UI can fall back to written instructions.
      expect(
        await BusAlarmService.instance
            .openAlarmSettings(AlarmSettingsTarget.notifications),
        isFalse,
      );
    });
  });

  group('ring time', () {
    test('always resolves to a future instant', () {
      final service = BusAlarmService.instance;

      // Whatever the wall clock says, a bus time that has already passed today
      // must roll to tomorrow rather than schedule into the past (an alarm in
      // the past is dropped by the OS and never rings).
      for (final label in ['12:05 AM', '8:30 AM', '11:59 PM']) {
        expect(
          service.parseTripTimeToDateTime(label).isAfter(DateTime.now()),
          isTrue,
          reason: '$label should resolve to an upcoming departure',
        );
      }
    });
  });
}
