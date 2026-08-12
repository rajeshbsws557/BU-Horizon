// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Pure, side-effect-free logic behind the "Next Bus Departure" spotlight.
//
// WHY THIS FILE EXISTS
// The spotlight card used to render `sections.first.trips.first` — the first
// row of the printed timetable — so at 9 PM it still advertised the 8:30 AM
// bus. It never consulted the clock and never rebuilt, which is exactly the
// "it's static / doesn't update at all" bug. All of the time reasoning now
// lives here as plain functions over an injected `now`, so it is unit
// testable without pumping widgets or waiting on wall-clock time.
import '../data/university_bus_schedule_data.dart';

/// Minutes since midnight for a "h:mm AM/PM" label, or null if unparseable.
///
/// Tolerates the shapes that actually appear in the bundled data and in live
/// Supabase rows: "8:30 AM", " 12:10 pm ", "9:00 PM".
int? parseClockMinutes(String raw) {
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp])[Mm]').firstMatch(raw.trim());
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour < 1 || hour > 12 || minute > 59) return null;

  final isPm = match.group(3)!.toUpperCase() == 'P';
  if (hour == 12) hour = 0; // 12 AM -> 00, 12 PM -> 12 (via the +12 below)
  if (isPm) hour += 12;
  return hour * 60 + minute;
}

/// A concrete, dated occurrence of a timetable trip.
class NextDeparture {
  /// Index of the owning [DepartureSection] in the list handed to the
  /// resolver. Lets callers rebuild the exact trip identity (route + place +
  /// time) that the alarm system keys off.
  final int sectionIndex;
  final String departurePlace;
  final BusTripItem trip;

  /// The wall-clock instant this bus leaves (today, or tomorrow after the last
  /// bus of the day has gone).
  final DateTime departsAt;

  /// True when [departsAt] rolled over to the next calendar day.
  final bool isTomorrow;

  const NextDeparture({
    required this.sectionIndex,
    required this.departurePlace,
    required this.trip,
    required this.departsAt,
    required this.isTomorrow,
  });

  /// Signed time remaining. Negative once the bus has pulled away.
  Duration timeUntil(DateTime now) => departsAt.difference(now);
}

/// Every remaining trip of the service day (plus tomorrow's wrap-around),
/// ordered by the instant each bus actually leaves.
///
/// A trip stays "upcoming" for [grace] after its scheduled minute so the card
/// can show a "Departing now" beat instead of skipping ahead the instant the
/// clock ticks over.
List<NextDeparture> resolveUpcomingDepartures(
  List<DepartureSection> sections, {
  required DateTime now,
  Duration grace = const Duration(minutes: 1),
}) {
  final today = DateTime(now.year, now.month, now.day);
  final departures = <NextDeparture>[];

  for (var s = 0; s < sections.length; s++) {
    final section = sections[s];
    for (final trip in section.trips) {
      final minutes = parseClockMinutes(trip.time);
      if (minutes == null) continue; // Unparseable label: never becomes "next".

      var departsAt = today.add(Duration(minutes: minutes));
      var isTomorrow = false;

      // Already gone (beyond the grace beat)? Its next occurrence is tomorrow,
      // which is what keeps the card useful late at night.
      if (departsAt.add(grace).isBefore(now)) {
        departsAt = DateTime(now.year, now.month, now.day + 1)
            .add(Duration(minutes: minutes));
        isTomorrow = true;
      }

      departures.add(
        NextDeparture(
          sectionIndex: s,
          departurePlace: section.departurePlace,
          trip: trip,
          departsAt: departsAt,
          isTomorrow: isTomorrow,
        ),
      );
    }
  }

  // Stable sort: equal times keep timetable (first-seen) order, so two buses
  // leaving at 4:10 PM from different points stay in the printed sequence.
  departures.sort((a, b) => a.departsAt.compareTo(b.departsAt));
  return departures;
}

/// The single next bus to leave, or null when no trip has a parseable time.
NextDeparture? resolveNextDeparture(
  List<DepartureSection> sections, {
  required DateTime now,
  Duration grace = const Duration(minutes: 1),
}) {
  final upcoming =
      resolveUpcomingDepartures(sections, now: now, grace: grace);
  return upcoming.isEmpty ? null : upcoming.first;
}

/// Human countdown for the spotlight card: "2h 14m", "12m 30s", "Now".
String formatCountdown(Duration remaining) {
  if (remaining.inSeconds <= 0) return 'Now';

  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  final seconds = remaining.inSeconds % 60;

  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  if (minutes > 0) {
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
  return '${seconds}s';
}
