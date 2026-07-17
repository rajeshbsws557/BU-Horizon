// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
class BusTripItem {
  final String time;
  final String busName;
  const BusTripItem({required this.time, required this.busName});
}

class DepartureSection {
  final String departurePlace;
  final List<BusTripItem> trips;
  const DepartureSection({required this.departurePlace, required this.trips});
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

  const UniversityBusCategory({
    required this.title,
    required this.routes,
  });
}

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
                BusTripItem(time: '12:10 PM', busName: 'কীর্তনখোলা, বিআরটিসি-০৬'),
                BusTripItem(time: '1:15 PM', busName: 'জয়ন্তী, বিআরটিসি-০৪'),
                BusTripItem(time: '2:15 PM', busName: 'বৈকালি, বিআরটিসি-০৬'),
                BusTripItem(time: '3:10 PM', busName: 'বিআরটিসি-০৪, ০৫'),
                BusTripItem(time: '4:10 PM', busName: 'চিত্রা, বিআরটিসি-০৪, ০৬'),
                BusTripItem(time: '5:10 PM', busName: 'বিআরটিসি-০৫'),
                BusTripItem(
                    time: '6:45 PM',
                    busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী'),
                BusTripItem(
                    time: '9:00 PM',
                    busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী'),
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
                BusTripItem(time: '1:00 PM', busName: 'কীর্তনখোলা, বিআরটিসি-০৬'),
                BusTripItem(time: '2:00 PM', busName: 'জয়ন্তী, বিআরটিসি-০৪'),
                BusTripItem(time: '3:00 PM', busName: 'বৈকালী, বিআরটিসি-০৬'),
                BusTripItem(time: '3:40 PM', busName: 'বিআরটিসি-০৪, ০৫'),
                BusTripItem(time: '4:40 PM', busName: 'চিত্রা'),
                BusTripItem(
                    time: '8:30 PM',
                    busName:
                        '২টি বাস (লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী)'),
                BusTripItem(
                    time: '9:30 PM',
                    busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী'),
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
                BusTripItem(
                    time: '10:15 AM', busName: 'আগুনমুখা, আন্ধারমানিক'),
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
                    time: '4:10 PM', busName: 'বিআরটিসি-০৮, ১০, ১২, ১৪'),
                BusTripItem(time: '5:10 PM', busName: 'বিআরটিসি-০৯'),
                BusTripItem(
                    time: '6:45 PM',
                    busName: 'লতা/কীর্তনখোলা/পায়রা/চিত্রা/বৈকালি/জয়ন্তী'),
                BusTripItem(time: '9:00 PM', busName: 'বিআরটিসি-১৩, ১৪'),
                BusTripItem(time: '10:00 PM', busName: 'বিআরটিসি-১৩, ১৪'),
              ],
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
              trips: [
                BusTripItem(time: '7:00 PM', busName: 'ইলিশা'),
              ],
            ),
            DepartureSection(
              departurePlace: 'চৌমাথা মোড়',
              trips: [
                BusTripItem(time: '7:30 AM', busName: 'মাইক্রো-০৪'),
              ],
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
              trips: [
                BusTripItem(time: '8:30 AM', busName: 'আগুনমুখা'),
              ],
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '4:05 PM', busName: 'আগুনমুখা'),
              ],
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
              trips: [
                BusTripItem(time: '8:30 AM', busName: 'কীর্তনখোলা'),
              ],
            ),
            DepartureSection(
              departurePlace: 'বিশ্ববিদ্যালয়',
              trips: [
                BusTripItem(time: '4:05 PM', busName: 'কীর্তনখোলা'),
              ],
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
              trips: [
                BusTripItem(time: '8:20 AM', busName: 'জয়ন্তী'),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
