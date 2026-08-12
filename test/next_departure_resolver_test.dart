// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Regression guard for the "Next Bus Departure is static" bug.
//
// The spotlight card used to render `sections.first.trips.first`, so it
// advertised the 8:30 AM bus at 9 PM and never changed. These tests pin the
// clock-aware behaviour that replaced it. Every case injects a fixed `now`, so
// they assert real logic rather than whatever time the suite happens to run at.
import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:bu_horizon/services/next_departure_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two departure points on one route, deliberately interleaved in time so a
/// naive "first section, first trip" implementation cannot pass.
const _sections = <DepartureSection>[
  DepartureSection(
    departurePlace: 'বিশ্ববিদ্যালয়',
    trips: [
      BusTripItem(time: '8:30 AM', busName: 'বৈকালি'),
      BusTripItem(time: '12:10 PM', busName: 'কীর্তনখোলা'),
      BusTripItem(time: '9:00 PM', busName: 'চিত্রা'),
    ],
  ),
  DepartureSection(
    departurePlace: 'রূপাতলী',
    trips: [
      BusTripItem(time: '10:15 AM', busName: 'সুগন্ধা'),
      BusTripItem(time: '4:40 PM', busName: 'সন্ধ্যা'),
    ],
  ),
];

DateTime _at(int hour, int minute) => DateTime(2026, 8, 5, hour, minute);

void main() {
  group('parseClockMinutes', () {
    test('parses the 12-hour labels used by the timetable', () {
      expect(parseClockMinutes('8:30 AM'), 8 * 60 + 30);
      expect(parseClockMinutes('12:10 PM'), 12 * 60 + 10); // noon, not midnight
      expect(parseClockMinutes('12:05 AM'), 5); // midnight, not noon
      expect(parseClockMinutes('9:00 PM'), 21 * 60);
      expect(parseClockMinutes(' 4:40 pm '), 16 * 60 + 40);
    });

    test('returns null for junk instead of guessing a time', () {
      expect(parseClockMinutes(''), isNull);
      expect(parseClockMinutes('TBA'), isNull);
      expect(parseClockMinutes('25:00 AM'), isNull);
    });
  });

  group('resolveNextDeparture', () {
    test('early morning: picks the first bus of the day', () {
      final next = resolveNextDeparture(_sections, now: _at(6, 0))!;

      expect(next.trip.time, '8:30 AM');
      expect(next.departurePlace, 'বিশ্ববিদ্যালয়');
      expect(next.isTomorrow, isFalse);
    });

    test('mid-morning: skips the bus that already left', () {
      // 9:00 AM — the 8:30 has gone; the genuinely next bus leaves from the
      // *second* section, which the old first-trip logic could never surface.
      final next = resolveNextDeparture(_sections, now: _at(9, 0))!;

      expect(next.trip.time, '10:15 AM');
      expect(next.departurePlace, 'রূপাতলী');
    });

    test('late night: rolls over to tomorrow\'s first bus', () {
      // 11:00 PM — every bus has gone. This is the exact scenario where the
      // card used to keep showing "8:30 AM" as if it were still coming.
      final next = resolveNextDeparture(_sections, now: _at(23, 0))!;

      expect(next.trip.time, '8:30 AM');
      expect(next.isTomorrow, isTrue);
      expect(next.departsAt, DateTime(2026, 8, 6, 8, 30));
    });

    test('keeps a just-departed bus visible during the grace window', () {
      // 30s after departure the bus is realistically still at the stop, so it
      // stays spotlighted rather than flicking to the next one.
      final next = resolveNextDeparture(
        _sections,
        now: _at(8, 30).add(const Duration(seconds: 30)),
      )!;

      expect(next.trip.time, '8:30 AM');
      expect(next.timeUntil(_at(8, 30).add(const Duration(seconds: 30))),
          const Duration(seconds: -30));
    });

    test('advances once the grace window has passed', () {
      final next = resolveNextDeparture(
        _sections,
        now: _at(8, 32),
      )!;

      expect(next.trip.time, '10:15 AM');
    });

    test('countdown shrinks as time advances (the card is not static)', () {
      final early = resolveNextDeparture(_sections, now: _at(7, 0))!;
      final later = resolveNextDeparture(_sections, now: _at(8, 0))!;

      expect(early.trip.time, later.trip.time); // same bus...
      expect(later.timeUntil(_at(8, 0)),
          lessThan(early.timeUntil(_at(7, 0)))); // ...less time left
    });

    test('ignores unparseable rows instead of spotlighting them', () {
      const withJunk = <DepartureSection>[
        DepartureSection(
          departurePlace: 'বিশ্ববিদ্যালয়',
          trips: [
            BusTripItem(time: 'TBA', busName: 'unknown'),
            BusTripItem(time: '10:15 AM', busName: 'সুগন্ধা'),
          ],
        ),
      ];

      final next = resolveNextDeparture(withJunk, now: _at(6, 0))!;
      expect(next.trip.time, '10:15 AM');
    });

    test('returns null when nothing can be parsed', () {
      const allJunk = <DepartureSection>[
        DepartureSection(
          departurePlace: 'বিশ্ববিদ্যালয়',
          trips: [BusTripItem(time: 'TBA', busName: 'unknown')],
        ),
      ];

      expect(resolveNextDeparture(allJunk, now: _at(6, 0)), isNull);
    });
  });

  group('resolveUpcomingDepartures', () {
    test('orders every remaining trip across all departure points', () {
      final upcoming = resolveUpcomingDepartures(_sections, now: _at(9, 0));

      expect(
        upcoming.map((d) => d.trip.time).toList(),
        ['10:15 AM', '12:10 PM', '4:40 PM', '9:00 PM', '8:30 AM'],
      );
      // Only the wrapped-around 8:30 AM belongs to tomorrow.
      expect(upcoming.last.isTomorrow, isTrue);
      expect(upcoming.take(4).every((d) => !d.isTomorrow), isTrue);
    });
  });

  group('formatCountdown', () {
    test('renders hours, minutes and seconds for the live badge', () {
      expect(formatCountdown(const Duration(hours: 2, minutes: 14)), '2h 14m');
      expect(formatCountdown(const Duration(minutes: 12, seconds: 30)),
          '12m 30s');
      expect(formatCountdown(const Duration(seconds: 45)), '45s');
      expect(formatCountdown(Duration.zero), 'Now');
      expect(formatCountdown(const Duration(seconds: -5)), 'Now');
    });
  });
}
