// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Regression guard for the operator-chip labels.
//
// The printed timetable names an operator once and then abbreviates its
// siblings to bare fleet numbers: 'বিআরটিসি-০৮, ১০, ১২, ১৪' is four BRTC buses,
// not one bus plus three loose numbers. Splitting on the separator alone
// rendered "১০" as its own chip — meaningless on its own, and tinted as a
// *different* operator because it no longer matched the BRTC test the renderers
// use to pick a colour.
//
// Both the Bus Schedule rows and the home Upcoming hero read their chips from
// [busOperatorChipLabels], so these tests pin the one shared expansion.
import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('busOperatorChipLabels', () {
    test('expands abbreviated fleet numbers to the operator named before them', () {
      expect(
        busOperatorChipLabels('বিআরটিসি-০৮, ১০, ১২, ১৪'),
        ['বিআরটিসি-০৮', 'বিআরটিসি-১০', 'বিআরটিসি-১২', 'বিআরটিসি-১৪'],
      );
    });

    test('carries the prefix across a named operator earlier in the string', () {
      expect(
        busOperatorChipLabels('চিত্রা, বিআরটিসি-০৪, ০৬'),
        ['চিত্রা', 'বিআরটিসি-০৪', 'বিআরটিসি-০৬'],
      );
    });

    test('leaves a fully named single operator untouched', () {
      expect(busOperatorChipLabels('বিআরটিসি-০৫'), ['বিআরটিসি-০৫']);
      expect(busOperatorChipLabels('কীর্তনখোলা'), ['কীর্তনখোলা']);
    });

    test('splits slash- and plus-separated pools', () {
      expect(
        busOperatorChipLabels(
          'সন্ধ্যা/সুগন্ধা/আন্ধারমানিক/আগুনমুখা (যেকোন ১টি)',
        ),
        ['সন্ধ্যা', 'সুগন্ধা', 'আন্ধারমানিক', 'আগুনমুখা (যেকোন ১টি)'],
      );
    });

    test('handles a non-BRTC numbered prefix', () {
      expect(
        busOperatorChipLabels('মাইক্রো-০২, ০৩'),
        ['মাইক্রো-০২', 'মাইক্রো-০৩'],
      );
    });

    test('passes a leading bare number through rather than guessing', () {
      expect(busOperatorChipLabels('০৬'), ['০৬']);
    });

    test('drops empty fragments and trims whitespace', () {
      expect(
        busOperatorChipLabels('  বিআরটিসি-০৮ ,  , ১০  '),
        ['বিআরটিসি-০৮', 'বিআরটিসি-১০'],
      );
      expect(busOperatorChipLabels(''), isEmpty);
    });

    test('every bundled operator string yields chips that name a bus', () {
      // The whole point of the expansion: no chip in the shipped timetable may
      // be a bare number, because a bare number names nothing.
      final bareNumber = RegExp(r'^[0-9০-৯]+$');
      for (final category in UniversityBusScheduleData.categories) {
        for (final route in category.routes) {
          for (final section in route.departureSections) {
            for (final trip in section.trips) {
              for (final label in busOperatorChipLabels(trip.busName)) {
                expect(
                  bareNumber.hasMatch(label),
                  isFalse,
                  reason:
                      '${route.routeName} ${trip.time} renders a bare "$label" '
                      'from "${trip.busName}".',
                );
              }
            }
          }
        }
      }
    });
  });
}
