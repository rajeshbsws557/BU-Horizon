// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
class BusTripItem {
  final String time;
  final String busName;
  const BusTripItem({required this.time, required this.busName});
}

/// Bengali (০–৯) and Latin digits — the timetable uses both.
const String _kFleetDigits = r'0-9০-৯';

/// An operator named in full, ending in a fleet number: "বিআরটিসি-০৮",
/// "মাইক্রো-০২". The prefix and separator are captured so an abbreviated
/// sibling can reuse them.
final RegExp _kNumberedOperator = RegExp(
  '^(.+?)([-–—])\\s*([$_kFleetDigits]+)\$',
);

/// A bare fleet number — how the timetable abbreviates a repeat of the operator
/// named immediately before it.
final RegExp _kBareFleetNumber = RegExp('^[$_kFleetDigits]+\$');

/// One chip label per bus behind a [BusTripItem.busName].
///
/// The printed timetable abbreviates a run of buses from one operator by naming
/// it once: `'বিআরটিসি-০৮, ১০, ১২, ১৪'` means BRTC 08, 10, 12 *and* 14. Splitting
/// on the separator alone left the abbreviated entries as bare numerals ("১০"),
/// which read as nothing at all — and, because they no longer matched the BRTC
/// test the renderers use to pick a colour, were tinted as if they belonged to a
/// different operator. One fleet now yields one consistently-labelled,
/// consistently-coloured set of chips.
///
/// A bare number with no operator named before it is passed through untouched
/// rather than guessed at.
List<String> busOperatorChipLabels(String busName) {
  final labels = <String>[];
  String? prefix;
  var separator = '-';

  for (final raw in busName.split(RegExp(r'[,/+]'))) {
    final part = raw.trim();
    if (part.isEmpty) continue;

    final numbered = _kNumberedOperator.firstMatch(part);
    if (numbered != null) {
      prefix = numbered.group(1)!.trim();
      separator = numbered.group(2)!;
      labels.add('$prefix$separator${numbered.group(3)}');
      continue;
    }

    if (prefix != null && _kBareFleetNumber.hasMatch(part)) {
      labels.add('$prefix$separator$part');
      continue;
    }

    labels.add(part);
  }

  return labels;
}

/// Which days a block of trips actually runs.
///
/// Most printed timetables carry no day qualifier, so they are [daily]. The
/// campus ⟷ রুপাতলী notice (Route 07) publishes two different timetables for
/// the same route — one for কর্মদিবস and one for the সাপ্তাহিক ছুটি — and
/// without this distinction the app would advertise a Friday-only 9:00 AM bus
/// on a Tuesday.
enum ServiceDays {
  /// No day restriction printed on the timetable.
  daily,

  /// Sunday–Thursday, the university's working days.
  workdays,

  /// Friday & Saturday, the weekly holiday.
  weekend,
}

extension ServiceDaysX on ServiceDays {
  /// Whether a bus in this block runs on [date].
  bool runsOn(DateTime date) {
    final isHoliday =
        date.weekday == DateTime.friday || date.weekday == DateTime.saturday;
    return switch (this) {
      ServiceDays.daily => true,
      ServiceDays.workdays => !isHoliday,
      ServiceDays.weekend => isHoliday,
    };
  }

  /// Short badge text. Empty for [ServiceDays.daily], which needs no label.
  String get shortLabel => switch (this) {
    ServiceDays.daily => '',
    ServiceDays.workdays => 'Sun–Thu',
    ServiceDays.weekend => 'Fri & Sat',
  };

  /// Longer form used by the day toggle and screen readers.
  String get longLabel => switch (this) {
    ServiceDays.daily => 'Every day',
    ServiceDays.workdays => 'Working days (Sun–Thu)',
    ServiceDays.weekend => 'Weekly holiday (Fri & Sat)',
  };

  /// Stable key for persistence and for the `bus_trips.service_days` column.
  /// Never rename these strings.
  String get storageKey => switch (this) {
    ServiceDays.daily => 'daily',
    ServiceDays.workdays => 'workdays',
    ServiceDays.weekend => 'weekend',
  };
}

/// Reads a [ServiceDays] back from its [ServiceDaysX.storageKey].
///
/// Unknown or missing values fall back to [ServiceDays.daily], so rows written
/// before the column existed — and alarms persisted by an older build — keep
/// their current all-days behaviour.
ServiceDays serviceDaysFromKey(String? key) => switch (key) {
  'workdays' => ServiceDays.workdays,
  'weekend' => ServiceDays.weekend,
  _ => ServiceDays.daily,
};

class DepartureSection {
  final String departurePlace;
  final List<BusTripItem> trips;

  /// The days this block of trips runs. Defaults to [ServiceDays.daily] so
  /// every existing route is unaffected.
  final ServiceDays serviceDays;

  /// Optional line shown under the section header — e.g. the notice's
  /// "নামাজ ও লাঞ্চের বিরতি", which is otherwise only visible as a missing row.
  final String? note;

  const DepartureSection({
    required this.departurePlace,
    required this.trips,
    this.serviceDays = ServiceDays.daily,
    this.note,
  });
}

class UniversityBusRoute {
  final String id;
  final String routeName;
  final String? routeDescription;
  final String? managerInfo;
  final List<DepartureSection> departureSections;

  const UniversityBusRoute({
    required this.id,
    required this.routeName,
    this.routeDescription,
    this.managerInfo,
    required this.departureSections,
  });
}

class UniversityBusCategory {
  final String title;
  final List<UniversityBusRoute> routes;

  const UniversityBusCategory({required this.title, required this.routes});
}

enum BusScheduleSource {
  /// Timetable packaged with the app. This is saved reference data, not an
  /// indication that the device has lost connectivity.
  bundled,

  /// Timetable fetched successfully from the configured backend.
  live,

  /// Previously fetched live data retained after a refresh failed.
  cachedOffline,
}

/// One paginated timetable response with an explicit data source.
class BusSchedulePage {
  final List<UniversityBusCategory> categories;
  final bool hasMore;
  final BusScheduleSource source;

  const BusSchedulePage({
    required this.categories,
    required this.hasMore,
    this.source = BusScheduleSource.live,
  });

  bool get isOffline => source == BusScheduleSource.cachedOffline;
}

/// Every Route 07 minibus is drawn from the same four-vehicle pool, so one
/// operator string is shared by all 38 trips. Slash-separated because
/// [busOperatorChipLabels] splits on `[,/+]` to render one pill per operator.
const String _route07Buses = 'সন্ধ্যা/সুগন্ধা/আন্ধারমানিক/আগুনমুখা (যেকোন ১টি)';

/// The notice prints "নামাজ ও লাঞ্চের বিরতি" between the 12:00 PM and 2:00 PM
/// rows. Stating it beats leaving users to infer it from a missing row.
const String _route07BreakNote =
    'নামাজ ও লাঞ্চের বিরতি — দুপুর ১:০০টায় কোন বাস নেই';

/// কর্মদিবস (Sun–Thu): evening service only, hourly 6:00 PM – 11:00 PM.
/// Identical in both directions, so both sections share this list.
const List<BusTripItem> _route07WorkdayTrips = [
  BusTripItem(time: '6:00 PM', busName: _route07Buses),
  BusTripItem(time: '7:00 PM', busName: _route07Buses),
  BusTripItem(time: '8:00 PM', busName: _route07Buses),
  BusTripItem(time: '9:00 PM', busName: _route07Buses),
  BusTripItem(time: '10:00 PM', busName: _route07Buses),
  BusTripItem(time: '11:00 PM', busName: _route07Buses),
];

/// সাপ্তাহিক ছুটি (Fri & Sat): hourly 9:00 AM – 10:00 PM with no 1:00 PM bus
/// (prayer + lunch break) and no 11:00 PM bus. Same in both directions.
const List<BusTripItem> _route07WeekendTrips = [
  BusTripItem(time: '9:00 AM', busName: _route07Buses),
  BusTripItem(time: '10:00 AM', busName: _route07Buses),
  BusTripItem(time: '11:00 AM', busName: _route07Buses),
  BusTripItem(time: '12:00 PM', busName: _route07Buses),
  // 1:00 PM — নামাজ ও লাঞ্চের বিরতি, no service.
  BusTripItem(time: '2:00 PM', busName: _route07Buses),
  BusTripItem(time: '3:00 PM', busName: _route07Buses),
  BusTripItem(time: '4:00 PM', busName: _route07Buses),
  BusTripItem(time: '5:00 PM', busName: _route07Buses),
  BusTripItem(time: '6:00 PM', busName: _route07Buses),
  BusTripItem(time: '7:00 PM', busName: _route07Buses),
  BusTripItem(time: '8:00 PM', busName: _route07Buses),
  BusTripItem(time: '9:00 PM', busName: _route07Buses),
  BusTripItem(time: '10:00 PM', busName: _route07Buses),
];

class UniversityBusScheduleData {
  static const List<UniversityBusCategory> categories = [
    UniversityBusCategory(
      title: 'Student',
      routes: [
        UniversityBusRoute(
          id: 'student_route_01',
          routeName: 'Route 01',
          routeDescription:
              'বরিশাল ক্লাব - বাংলাবাজার মোড় - নূরিয়া স্কুল - আমতলার মোড় - রূপাতলী হাউজিং - কাঠালতলা - টোলঘর - বিশ্ববিদ্যালয়',
          departureSections: [
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '8:30 AM', busName: 'বৈকালি, বিআরটিসি-০৬'),
                BusTripItem(time: '9:30 AM', busName: 'চিত্রা, বিআরটিসি-০৫'),
                BusTripItem(time: '10:30 AM', busName: 'বিআরটিসি-০৪'),
                BusTripItem(time: '11:15 AM', busName: 'বিআরটিসি-০৫'),
                BusTripItem(
                  time: '12:10 PM',
                  busName: 'কীর্তনখোলা, বিআরটিসি-০৬',
                ),
                BusTripItem(time: '1:15 PM', busName: 'জয়ন্তী, বিআরটিসি-০৪'),
                BusTripItem(time: '2:15 PM', busName: 'বৈকালি, বিআরটিসি-০৬'),
                BusTripItem(time: '3:10 PM', busName: 'বিআরটিসি-০৪, ০৫'),
                BusTripItem(
                  time: '4:10 PM',
                  busName: 'চিত্রা, বিআরটিসি-০৪, ০৬',
                ),
                BusTripItem(time: '5:10 PM', busName: 'বিআরটিসি-০৫'),
                BusTripItem(
                  time: '6:45 PM',
                  busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী',
                ),
                BusTripItem(
                  time: '9:00 PM',
                  busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী',
                ),
              ],
            ),
            DepartureSection(
              departurePlace: 'বরিশাল ক্লাব',
              trips: [
                BusTripItem(time: '7:30 AM', busName: 'বিআরটিসি-০৬'),
                BusTripItem(time: '8:30 AM', busName: 'বিআরটিসি-০৪, ০৫'),
                BusTripItem(time: '9:15 AM', busName: 'বৈকালি, বিআরটিসি-০৬'),
                BusTripItem(time: '10:15 AM', busName: 'চিত্রা, বিআরটিসি-০৫'),
                BusTripItem(time: '11:15 AM', busName: 'বিআরটিসি-০৪'),
                BusTripItem(time: '12:00 PM', busName: 'বিআরটিসি-০৫'),
                BusTripItem(
                  time: '1:00 PM',
                  busName: 'কীর্তনখোলা, বিআরটিসি-০৬',
                ),
                BusTripItem(time: '2:00 PM', busName: 'জয়ন্তী, বিআরটিসি-০৪'),
                BusTripItem(time: '3:00 PM', busName: 'বৈকালী, বিআরটিসি-০৬'),
                BusTripItem(time: '3:40 PM', busName: 'বিআরটিসি-০৪, ০৫'),
                BusTripItem(time: '4:40 PM', busName: 'চিত্রা'),
                BusTripItem(
                  time: '8:30 PM',
                  busName:
                      '২টি বাস (লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী)',
                ),
                BusTripItem(
                  time: '9:30 PM',
                  busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী',
                ),
              ],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'student_route_02',
          routeName: 'Route 02',
          routeDescription:
              'নতুন বাজার (টেম্পুস্ট্যান্ড) - মুন্সি গ্যারেজ - অপসোনিন মোড় - বটতলার মোড় - করিমকুটির - বিশ্ববিদ্যালয়',
          departureSections: [
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '7:45 AM', busName: 'সুগন্ধা'),
                BusTripItem(time: '8:30 AM', busName: 'সন্ধ্যা'),
                BusTripItem(time: '9:30 AM', busName: 'আগুনমুখা'),
                BusTripItem(time: '10:30 AM', busName: 'সুগন্ধা'),
                BusTripItem(time: '11:15 AM', busName: 'সন্ধ্যা'),
                BusTripItem(time: '12:10 PM', busName: 'আগুনমুখা'),
                BusTripItem(time: '1:15 PM', busName: 'সুগন্ধা'),
                BusTripItem(time: '2:15 PM', busName: 'আন্ধারমানিক'),
                BusTripItem(time: '3:10 PM', busName: 'সন্ধ্যা'),
                BusTripItem(time: '4:10 PM', busName: 'সন্ধ্যা, সুগন্ধা'),
              ],
            ),
            DepartureSection(
              departurePlace: 'নতুন বাজার (টেম্পুস্ট্যান্ড)',
              trips: [
                BusTripItem(time: '7:30 AM', busName: 'আন্ধারমানিক'),
                BusTripItem(time: '8:30 AM', busName: 'সুগন্ধা'),
                BusTripItem(time: '9:15 AM', busName: 'সন্ধ্যা'),
                BusTripItem(time: '10:15 AM', busName: 'আগুনমুখা, আন্ধারমানিক'),
                BusTripItem(time: '11:15 AM', busName: 'সুগন্ধা'),
                BusTripItem(time: '12:00 PM', busName: 'সন্ধ্যা'),
                BusTripItem(time: '12:45 PM', busName: 'আগুনমুখা'),
                BusTripItem(time: '1:50 PM', busName: 'সুগন্ধা'),
                BusTripItem(time: '2:45 PM', busName: 'আন্ধারমানিক'),
                BusTripItem(time: '3:40 PM', busName: 'সন্ধ্যা'),
                BusTripItem(time: '4:40 PM', busName: 'সুগন্ধা'),
              ],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'student_route_03',
          routeName: 'Route 03',
          routeDescription:
              'নথুল্লাবাদ ব্রীজের ঢাল - কলেজ এভিনিউ - টিটিসি মূল গেট - চৌমাথা মোড় - খানা কাউন্সিলের মূল গেট - আমতলার মোড় - রূপাতলী হাউজিং - কাঁঠালতলা - টোলঘর - বিশ্ববিদ্যালয়',
          departureSections: [
            DepartureSection(
              departurePlace: 'নথুল্লাবাদ ব্রীজের ঢাল',
              trips: [
                BusTripItem(time: '7:30 AM', busName: 'বিআরটিসি-০৭'),
                BusTripItem(time: '8:30 AM', busName: 'বিআরটিসি-০৮, ১১'),
                BusTripItem(time: '9:15 AM', busName: 'বিআরটিসি-০৯, ১০'),
                BusTripItem(time: '10:15 AM', busName: 'বিআরটিসি-১২, ১৩, ১৪'),
                BusTripItem(time: '11:15 AM', busName: 'বিআরটিসি-০৭, ১১'),
                BusTripItem(time: '12:00 PM', busName: 'বিআরটিসি-০৮, ০৯'),
                BusTripItem(time: '12:30 PM', busName: 'বিআরটিসি-১০, ১২'),
                BusTripItem(time: '1:00 PM', busName: 'বিআরটিসি-০৭, ১৩'),
                BusTripItem(time: '2:00 PM', busName: 'বিআরটিসি-০৮'),
                BusTripItem(time: '3:00 PM', busName: 'বিআরটিসি-১৪'),
                BusTripItem(time: '3:30 PM', busName: 'বিআরটিসি-১২'),
                BusTripItem(time: '4:30 PM', busName: 'বিআরটিসি-০৯'),
                BusTripItem(time: '8:30 PM', busName: 'বিআরটিসি-১৩, ১৪'),
                BusTripItem(time: '9:30 PM', busName: 'বিআরটিসি-১৩, ১৪'),
              ],
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '8:30 AM', busName: 'বিআরটিসি-০৭'),
                BusTripItem(time: '9:30 AM', busName: 'বিআরটিসি-০৮, ১১'),
                BusTripItem(time: '10:00 AM', busName: 'বিআরটিসি-০৯, ১০'),
                BusTripItem(time: '11:15 AM', busName: 'বিআরটিসি-১২, ১৩'),
                BusTripItem(time: '12:10 PM', busName: 'বিআরটিসি-০৭, ১১'),
                BusTripItem(time: '1:15 PM', busName: 'বিআরটিসি-০৮, ০৯'),
                BusTripItem(time: '2:15 PM', busName: 'বিআরটিসি-১২, ১৪'),
                BusTripItem(time: '3:10 PM', busName: 'বিআরটিসি-০৭, ১৩'),
                BusTripItem(
                  time: '4:10 PM',
                  busName: 'বিআরটিসি-০৮, ১০, ১২, ১৪',
                ),
                BusTripItem(time: '5:10 PM', busName: 'বিআরটিসি-০৯'),
                BusTripItem(
                  time: '6:45 PM',
                  busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী',
                ),
                BusTripItem(time: '9:00 PM', busName: 'বিআরটিসি-১৩, ১৪'),
                BusTripItem(time: '10:00 PM', busName: 'বিআরটিসি-১৩, ১৪'),
              ],
            ),
          ],
        ),
        // Route 07 — পরিবহন পুল নোটিস-০৮/২০২০/১০৭৮ (১০.০৮.২০২৬), effective
        // ১১.০৮.২০২৬. This is the only route that publishes two different
        // timetables: an evening-only service on কর্মদিবস and a near all-day
        // service on the সাপ্তাহিক ছুটি. Hence the [ServiceDays] split — a
        // flattened list would show a Friday-only 9:00 AM bus on a Tuesday.
        UniversityBusRoute(
          id: 'student_route_07',
          routeName: 'Route 07',
          routeDescription:
              'বরিশাল বিশ্ববিদ্যালয় - টোল প্লাজা - সোনারগাঁও টেক্সটাইল - পল্লী বিদ্যুৎ সমিতি মসজিদ - রেইনট্রি তলা - খালেক সড়ক - কাঠালতলা - নতুন আবাসিক - রুপাতলী',
          managerInfo:
              'পরিবহন পুল, বরিশাল বিশ্ববিদ্যালয় · নোটিস-০৮/২০২০/১০৭৮ · কার্যকর ১১.০৮.২০২৬',
          departureSections: [
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              serviceDays: ServiceDays.workdays,
              trips: _route07WorkdayTrips,
            ),
            DepartureSection(
              departurePlace: 'রুপাতলী (লিলি ফিলিং স্টেশনের বিপরীত পার্শ্ব)',
              serviceDays: ServiceDays.workdays,
              trips: _route07WorkdayTrips,
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              serviceDays: ServiceDays.weekend,
              note: _route07BreakNote,
              trips: _route07WeekendTrips,
            ),
            DepartureSection(
              departurePlace: 'রুপাতলী (লিলি ফিলিং স্টেশনের বিপরীত পার্শ্ব)',
              serviceDays: ServiceDays.weekend,
              note: _route07BreakNote,
              trips: _route07WeekendTrips,
            ),
          ],
        ),
      ],
    ),
    UniversityBusCategory(
      title: 'Teacher',
      routes: [
        UniversityBusRoute(
          id: 'teacher_route_04',
          routeName: 'Route 04',
          departureSections: [
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '2:00 PM', busName: 'মাইক্রো-০৪'),
                BusTripItem(time: '4:05 PM', busName: 'নয়াভাঙ্গানী'),
              ],
            ),
            DepartureSection(
              departurePlace: 'চৌমাথা মোড়',
              trips: [
                BusTripItem(time: '8:30 AM', busName: 'নয়াভাঙ্গানী'),
                BusTripItem(time: '9:50 AM', busName: 'নয়াভাঙ্গানী'),
                BusTripItem(time: '12:00 PM', busName: 'মাইক্রো-০২'),
              ],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'teacher_route_05',
          routeName: 'Route 05',
          departureSections: [
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [BusTripItem(time: '7:00 PM', busName: 'ইলিশা')],
            ),
            DepartureSection(
              departurePlace: 'চৌমাথা মোড়',
              trips: [BusTripItem(time: '7:30 AM', busName: 'মাইক্রো-০৪')],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'teacher_route_06',
          routeName: 'Route 06',
          departureSections: [
            DepartureSection(
              departurePlace: 'চৌমাথা মোড়',
              trips: [
                BusTripItem(time: '8:30 AM', busName: 'ইলিশা'),
                BusTripItem(time: '10:00 AM', busName: 'লতা'),
                BusTripItem(time: '12:00 PM', busName: 'ইলিশা'),
              ],
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '2:00 PM', busName: 'নয়াভাঙ্গানী'),
                BusTripItem(time: '4:05 PM', busName: 'লতা'),
              ],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'teacher_route_07',
          routeName: 'Route 07',
          departureSections: [
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '2:00 PM', busName: 'মাইক্রো-০৩'),
                BusTripItem(time: '4:05 PM', busName: 'মাইক্রো-০৩'),
              ],
            ),
            DepartureSection(
              departurePlace: 'ট্রাস্ট ভবন',
              trips: [
                BusTripItem(time: '9:00 AM', busName: 'মাইক্রো-০৩'),
                BusTripItem(time: '10:30 AM', busName: 'মাইক্রো-০৩'),
                BusTripItem(time: '12:30 PM', busName: 'মাইক্রো-০৩'),
              ],
            ),
          ],
        ),
      ],
    ),
    UniversityBusCategory(
      title: 'Staff',
      routes: [
        UniversityBusRoute(
          id: 'staff_route_04',
          routeName: 'Route 04',
          departureSections: [
            DepartureSection(
              departurePlace: 'চৌমাথা মোড়',
              trips: [BusTripItem(time: '8:30 AM', busName: 'আগুনমুখা')],
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [BusTripItem(time: '4:05 PM', busName: 'আগুনমুখা')],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'staff_route_05',
          routeName: 'Route 05',
          departureSections: [
            DepartureSection(
              departurePlace: 'চৌমাথা মোড়',
              trips: [
                BusTripItem(time: '8:25 AM', busName: 'মাইক্রো-০৫'),
                BusTripItem(time: '8:25 AM', busName: 'আন্ধারমানিক'),
              ],
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '4:05 PM', busName: 'মাইক্রো-০৫'),
                BusTripItem(time: '4:10 PM', busName: 'সুগন্ধা'),
              ],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'staff_route_06',
          routeName: 'Route 06',
          departureSections: [
            DepartureSection(
              departurePlace: 'চৌমাথা মোড়',
              trips: [BusTripItem(time: '8:30 AM', busName: 'কীর্তনখোলা')],
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [BusTripItem(time: '4:05 PM', busName: 'কীর্তনখোলা')],
            ),
          ],
        ),
        UniversityBusRoute(
          id: 'staff_route_08',
          routeName: 'Route 08',
          departureSections: [
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '4:10 PM', busName: 'বৈকালি'),
                BusTripItem(time: '4:10 PM', busName: 'জয়ন্তী'),
              ],
            ),
            DepartureSection(
              departurePlace: 'নথুল্লাবাদ',
              trips: [BusTripItem(time: '8:20 AM', busName: 'জয়ন্তী')],
            ),
          ],
        ),
      ],
    ),
  ];
}
