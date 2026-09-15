// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Data guard for Route 07 (বরিশাল বিশ্ববিদ্যালয় ⟷ রুপাতলী), from Transport Pool
// notice বিইউ/রেজি/পরিবহন পুল/নোটিস-০৮/২০২০/১০৭৮ dated ১০.০৮.২০২৬.
//
// A timetable is the one kind of data where a silent edit is invisible in
// review but wrong on a bus stop at 11 PM. These assertions transcribe the
// printed notice, so dropping a departure, mislabelling a day pattern or
// accidentally adding the 1:00 PM weekend bus fails here rather than shipping.
import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// কর্মদিবস: hourly, 6:00 PM – 11:00 PM.
const _workdayTimes = [
  '6:00 PM',
  '7:00 PM',
  '8:00 PM',
  '9:00 PM',
  '10:00 PM',
  '11:00 PM',
];

/// সাপ্তাহিক ছুটি: hourly, 9:00 AM – 10:00 PM, with no 1:00 PM bus.
const _weekendTimes = [
  '9:00 AM',
  '10:00 AM',
  '11:00 AM',
  '12:00 PM',
  '2:00 PM',
  '3:00 PM',
  '4:00 PM',
  '5:00 PM',
  '6:00 PM',
  '7:00 PM',
  '8:00 PM',
  '9:00 PM',
  '10:00 PM',
];

const _campus = 'বিশ্ববিদ্যালয়';
const _rupatoli = 'রুপাতলী (লিলি ফিলিং স্টেশনের বিপরীত পার্শ্ব)';

void main() {
  final student = UniversityBusScheduleData.categories.firstWhere(
    (category) => category.title == 'Student',
  );
  final route = student.routes.firstWhere((r) => r.id == 'student_route_07');

  List<BusTripItem> tripsFor(String place, ServiceDays days) => route
      .departureSections
      .firstWhere(
        (s) => s.departurePlace == place && s.serviceDays == days,
        orElse: () => throw StateError('no $place / ${days.storageKey} section'),
      )
      .trips;

  test('is a Student route named Route 07 and does not replace 01–03', () {
    expect(route.routeName, 'Route 07');
    // The existing routes stay active; this notice adds a service.
    expect(
      student.routes.map((r) => r.id),
      containsAll(<String>[
        'student_route_01',
        'student_route_02',
        'student_route_03',
        'student_route_07',
      ]),
    );
  });

  test('publishes exactly two timetables in both directions', () {
    expect(route.departureSections.length, 4);
    expect(
      route.departureSections.map((s) => s.serviceDays).toSet(),
      {ServiceDays.workdays, ServiceDays.weekend},
    );
    // Both directions exist for each pattern.
    for (final days in [ServiceDays.workdays, ServiceDays.weekend]) {
      expect(
        route.departureSections
            .where((s) => s.serviceDays == days)
            .map((s) => s.departurePlace)
            .toSet(),
        {_campus, _rupatoli},
      );
    }
  });

  test('কর্মদিবস timetable is 6 PM–11 PM hourly, both ways', () {
    expect(tripsFor(_campus, ServiceDays.workdays).map((t) => t.time).toList(),
        _workdayTimes);
    expect(tripsFor(_rupatoli, ServiceDays.workdays).map((t) => t.time).toList(),
        _workdayTimes);
  });

  test('সাপ্তাহিক ছুটি timetable is 9 AM–10 PM hourly, both ways', () {
    expect(tripsFor(_campus, ServiceDays.weekend).map((t) => t.time).toList(),
        _weekendTimes);
    expect(tripsFor(_rupatoli, ServiceDays.weekend).map((t) => t.time).toList(),
        _weekendTimes);
  });

  test('has no 1:00 PM weekend bus — that slot is the নামাজ ও লাঞ্চের বিরতি',
      () {
    for (final place in [_campus, _rupatoli]) {
      expect(
        tripsFor(place, ServiceDays.weekend).map((t) => t.time),
        isNot(contains('1:00 PM')),
      );
    }
    // And the break is stated, not left as an unexplained gap.
    for (final section in route.departureSections.where(
      (s) => s.serviceDays == ServiceDays.weekend,
    )) {
      expect(section.note, contains('নামাজ ও লাঞ্চের বিরতি'));
    }
  });

  test('runs no bus on a workday morning or a weekend 11 PM', () {
    // Reads the two windows back as behaviour rather than as literals.
    for (final place in [_campus, _rupatoli]) {
      final workdayHours = tripsFor(place, ServiceDays.workdays)
          .map((t) => t.time)
          .toList();
      expect(workdayHours.any((t) => t.endsWith('AM')), isFalse);

      final weekendHours = tripsFor(place, ServiceDays.weekend)
          .map((t) => t.time)
          .toList();
      expect(weekendHours, isNot(contains('11:00 PM')));
    }
  });

  test('every trip names the four-vehicle operator pool', () {
    for (final section in route.departureSections) {
      for (final trip in section.trips) {
        for (final operator in const [
          'সন্ধ্যা',
          'সুগন্ধা',
          'আন্ধারমানিক',
          'আগুনমুখা',
        ]) {
          expect(trip.busName, contains(operator));
        }
      }
    }
  });

  test('the printed stop list starts at campus and ends at রুপাতলী', () {
    final stops = route.routeDescription!
        .split(RegExp(r'\s*-\s*'))
        .map((s) => s.trim())
        .toList();
    expect(stops.first, contains('বিশ্ববিদ্যালয়'));
    expect(stops.last, 'রুপাতলী');
    expect(
      stops,
      containsAll(<String>[
        'টোল প্লাজা',
        'সোনারগাঁও টেক্সটাইল',
        'পল্লী বিদ্যুৎ সমিতি মসজিদ',
        'রেইনট্রি তলা',
        'খালেক সড়ক',
        'কাঠালতলা',
        'নতুন আবাসিক',
      ]),
    );
  });

  test('38 departures in total, matching the notice', () {
    final total = route.departureSections.fold<int>(
      0,
      (count, section) => count + section.trips.length,
    );
    expect(total, (_workdayTimes.length + _weekendTimes.length) * 2);
    expect(total, 38);
  });
}
