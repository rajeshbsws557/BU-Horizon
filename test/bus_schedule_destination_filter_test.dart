// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Guards the "Where to go?" filter against the direction inversion it used to
// have: picking a destination matched trips *departing* from that place, so
// "take me to the university" listed every bus leaving the university.
//
// Place names are read out of the bundled timetable rather than typed as
// literals here — the Bangla strings have several visually identical
// encodings, and a hand-typed copy silently fails to compare equal.
import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:bu_horizon/screens/bus_schedule_screen.dart';
import 'package:flutter_test/flutter_test.dart';

UniversityBusCategory _category(String title) =>
    UniversityBusScheduleData.categories.firstWhere((c) => c.title == title);

UniversityBusRoute _route(String category, String id) =>
    _category(category).routes.firstWhere((r) => r.id == id);

/// The campus place name exactly as the timetable spells it. Route 01 lists the
/// campus first, and it is the only place shared by every student route.
final String campus = _route('Student', 'student_route_01')
    .departureSections
    .first
    .departurePlace;

bool _isCampus(String place) => place.contains(campus);

void main() {
  group('destinationsForSection', () {
    test('a bus leaving the campus never counts as going to the campus', () {
      for (final category in UniversityBusScheduleData.categories) {
        for (final route in category.routes) {
          for (final section in route.departureSections) {
            if (!_isCampus(section.departurePlace)) continue;
            expect(
              destinationsForSection(route, section).any(_isCampus),
              isFalse,
              reason: '${category.title} ${route.routeName}: campus-outbound '
                  'trips must not be offered as going to the campus',
            );
          }
        }
      }
    });

    test('a city-terminal trip reaches the campus, via its in-between stops',
        () {
      final route = _route('Student', 'student_route_01');
      final citySection =
          route.departureSections.firstWhere((s) => !_isCampus(s.departurePlace));

      final destinations = destinationsForSection(route, citySection);

      // The printed stop list is walked in travel order, so the campus is the
      // end of the line and the stops before it are reachable too.
      expect(destinations.last, campus);
      expect(destinations.length, greaterThan(1));
      expect(destinations, isNot(contains(citySection.departurePlace)));
    });

    test('campus-outbound trips reach the city terminal', () {
      final route = _route('Student', 'student_route_01');
      final campusSection =
          route.departureSections.firstWhere((s) => _isCampus(s.departurePlace));
      final citySection =
          route.departureSections.firstWhere((s) => !_isCampus(s.departurePlace));

      expect(
        destinationsForSection(route, campusSection),
        contains(citySection.departurePlace),
      );
    });

    test('routes without a printed stop list fall back to the opposite terminal',
        () {
      // Teacher routes carry no routeDescription, so the other departure
      // section is the only direction signal available.
      final route = _route('Teacher', 'teacher_route_04');
      expect(route.routeDescription, anyOf(isNull, isEmpty));

      final campusSection =
          route.departureSections.firstWhere((s) => _isCampus(s.departurePlace));
      final citySection =
          route.departureSections.firstWhere((s) => !_isCampus(s.departurePlace));

      expect(
        destinationsForSection(route, campusSection),
        equals([citySection.departurePlace]),
      );
    });
  });

  group('primaryDestinationFor', () {
    test('is the opposite terminal of the route', () {
      final route = _route('Student', 'student_route_02');
      final campusSection =
          route.departureSections.firstWhere((s) => _isCampus(s.departurePlace));
      final citySection =
          route.departureSections.firstWhere((s) => !_isCampus(s.departurePlace));

      expect(primaryDestinationFor(route, campusSection),
          citySection.departurePlace);
      expect(primaryDestinationFor(route, citySection), campus);
    });
  });
}
