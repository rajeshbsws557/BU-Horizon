// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BusStopLocation {
  final String id;
  final String name;
  final String englishName;
  final LatLng point;
  final String description;

  const BusStopLocation({
    required this.id,
    required this.name,
    required this.englishName,
    required this.point,
    required this.description,
  });
}

class BusMapRouteData {
  final String routeId;
  final String routeName;
  final Color color;
  final List<LatLng> pathPoints;
  final List<BusStopLocation> keyStops;

  const BusMapRouteData({
    required this.routeId,
    required this.routeName,
    required this.color,
    required this.pathPoints,
    required this.keyStops,
  });
}

class BarishalBusRouteCoordinates {
  static const LatLng buCampusPoint = LatLng(22.6581, 90.3552);

  // Main Bus Stops in Barishal City
  static const BusStopLocation buCampus = BusStopLocation(
    id: 'bu_campus',
    name: 'বিশ্ববিদ্যালয় (BU Campus)',
    englishName: 'Barishal University Main Gate',
    point: LatLng(22.6581, 90.3552),
    description: 'Main Campus Terminal & Drop-off Point',
  );

  static const BusStopLocation barishalClub = BusStopLocation(
    id: 'barishal_club',
    name: 'বরিশাল ক্লাব (Barishal Club)',
    englishName: 'Barishal Club',
    point: LatLng(22.7010, 90.3705),
    description: 'Route 01 Starting Point in Sadar',
  );

  static const BusStopLocation banglabazar = BusStopLocation(
    id: 'banglabazar',
    name: 'বাংলাবাজার মোড়',
    englishName: 'Banglabazar Mor',
    point: LatLng(22.6935, 90.3660),
    description: 'Major student boarding stop',
  );

  static const BusStopLocation nuriyaSchool = BusStopLocation(
    id: 'nuriya_school',
    name: 'নূরিয়া স্কুল',
    englishName: 'Nuriya School',
    point: LatLng(22.6880, 90.3630),
    description: 'City stop near Nuriya High School',
  );

  static const BusStopLocation amtalarMor = BusStopLocation(
    id: 'amtalar_mor',
    name: 'আমতলার মোড়',
    englishName: 'Amtala Mor',
    point: LatLng(22.6800, 90.3580),
    description: 'Junction point for Route 01 & Route 03',
  );

  static const BusStopLocation rupataliHousing = BusStopLocation(
    id: 'rupatali_housing',
    name: 'রূপাতলী হাউজিং',
    englishName: 'Rupatali Housing',
    point: LatLng(22.6710, 90.3520),
    description: 'Residential area bus stop',
  );

  static const BusStopLocation kathaltala = BusStopLocation(
    id: 'kathaltala',
    name: 'কাঁঠালতলা',
    englishName: 'Kathaltala',
    point: LatLng(22.6650, 90.3535),
    description: 'Highway stop before Tolghat',
  );

  static const BusStopLocation tolghat = BusStopLocation(
    id: 'tolghat',
    name: 'টোলঘর',
    englishName: 'Tolghat Bridge',
    point: LatLng(22.6610, 90.3545),
    description: 'Kirtonkhola river bridge toll gate',
  );

  static const BusStopLocation nutanBazar = BusStopLocation(
    id: 'nutan_bazar',
    name: 'নতুন বাজার (টেম্পুস্ট্যান্ড)',
    englishName: 'Nutan Bazar Tempu Stand',
    point: LatLng(22.7090, 90.3680),
    description: 'Route 02 Northern Origin',
  );

  static const BusStopLocation munshiGarage = BusStopLocation(
    id: 'munshi_garage',
    name: 'মুন্সি গ্যারেজ',
    englishName: 'Munshi Garage',
    point: LatLng(22.7030, 90.3650),
    description: 'Route 02 stop',
  );

  static const BusStopLocation opsoninMor = BusStopLocation(
    id: 'opsonin_mor',
    name: 'অপসোনিন মোড়',
    englishName: 'Opsonin Mor',
    point: LatLng(22.6970, 90.3620),
    description: 'Route 02 industrial junction',
  );

  static const BusStopLocation bottolarMor = BusStopLocation(
    id: 'bottolar_mor',
    name: 'বটতলার মোড়',
    englishName: 'Bottola Mor',
    point: LatLng(22.6910, 90.3590),
    description: 'Route 02 central stop',
  );

  static const BusStopLocation korimkutir = BusStopLocation(
    id: 'korimkutir',
    name: 'করিমকুটির',
    englishName: 'Korimkutir',
    point: LatLng(22.6780, 90.3560),
    description: 'Route 02 southern junction',
  );

  static const BusStopLocation nathullabad = BusStopLocation(
    id: 'nathullabad',
    name: 'নথুল্লাবাদ ব্রীজের ঢাল',
    englishName: 'Nathullabad Bridge Dhal',
    point: LatLng(22.7160, 90.3510),
    description: 'Route 03 Central Bus Terminal Hub',
  );

  static const BusStopLocation collegeAvenue = BusStopLocation(
    id: 'college_avenue',
    name: 'কলেজ এভিনিউ',
    englishName: 'College Avenue',
    point: LatLng(22.7100, 90.3540),
    description: 'Route 03 educational area',
  );

  static const BusStopLocation ttcGate = BusStopLocation(
    id: 'ttc_gate',
    name: 'টিটিসি মূল গেট',
    englishName: 'TTC Main Gate',
    point: LatLng(22.7050, 90.3560),
    description: 'Teachers Training College stop',
  );

  static const BusStopLocation choumatha = BusStopLocation(
    id: 'choumatha',
    name: 'চৌমাথা মোড়',
    englishName: 'Choumatha Mor',
    point: LatLng(22.7000, 90.3570),
    description: 'Major intersection for Route 03 & Teacher routes',
  );

  static const BusStopLocation khanaCouncil = BusStopLocation(
    id: 'khana_council',
    name: 'খানা কাউন্সিলের মূল গেট',
    englishName: 'Khana Council Gate',
    point: LatLng(22.6890, 90.3575),
    description: 'Route 03 stop',
  );

  // Detailed Polyline paths for each University Route
  static final List<BusMapRouteData> allRoutes = [
    BusMapRouteData(
      routeId: 'student_route_01',
      routeName: 'Route 01 (বরিশাল ক্লাব)',
      color: const Color(0xFF2E7DF6), // Blue
      pathPoints: const [
        LatLng(22.7010, 90.3705), // Barishal Club
        LatLng(22.6970, 90.3685),
        LatLng(22.6935, 90.3660), // Banglabazar
        LatLng(22.6880, 90.3630), // Nuriya School
        LatLng(22.6800, 90.3580), // Amtala Mor
        LatLng(22.6710, 90.3520), // Rupatali Housing
        LatLng(22.6650, 90.3535), // Kathaltala
        LatLng(22.6610, 90.3545), // Tolghat
        LatLng(22.6581, 90.3552), // BU Campus
      ],
      keyStops: const [
        barishalClub,
        banglabazar,
        nuriyaSchool,
        amtalarMor,
        rupataliHousing,
        kathaltala,
        tolghat,
        buCampus,
      ],
    ),
    BusMapRouteData(
      routeId: 'student_route_02',
      routeName: 'Route 02 (নতুন বাজার)',
      color: const Color(0xFF00E5FF), // Cyan
      pathPoints: const [
        LatLng(22.7090, 90.3680), // Nutan Bazar
        LatLng(22.7030, 90.3650), // Munshi Garage
        LatLng(22.6970, 90.3620), // Opsonin Mor
        LatLng(22.6910, 90.3590), // Bottolar Mor
        LatLng(22.6780, 90.3560), // Korimkutir
        LatLng(22.6650, 90.3535), // Kathaltala
        LatLng(22.6610, 90.3545), // Tolghat
        LatLng(22.6581, 90.3552), // BU Campus
      ],
      keyStops: const [
        nutanBazar,
        munshiGarage,
        opsoninMor,
        bottolarMor,
        korimkutir,
        kathaltala,
        tolghat,
        buCampus,
      ],
    ),
    BusMapRouteData(
      routeId: 'student_route_03',
      routeName: 'Route 03 (নথুল্লাবাদ)',
      color: const Color(0xFFFF9100), // Amber/Orange
      pathPoints: const [
        LatLng(22.7160, 90.3510), // Nathullabad
        LatLng(22.7100, 90.3540), // College Avenue
        LatLng(22.7050, 90.3560), // TTC Gate
        LatLng(22.7000, 90.3570), // Choumatha
        LatLng(22.6890, 90.3575), // Khana Council
        LatLng(22.6800, 90.3580), // Amtala Mor
        LatLng(22.6710, 90.3520), // Rupatali Housing
        LatLng(22.6650, 90.3535), // Kathaltala
        LatLng(22.6610, 90.3545), // Tolghat
        LatLng(22.6581, 90.3552), // BU Campus
      ],
      keyStops: const [
        nathullabad,
        collegeAvenue,
        ttcGate,
        choumatha,
        khanaCouncil,
        amtalarMor,
        rupataliHousing,
        kathaltala,
        tolghat,
        buCampus,
      ],
    ),
    BusMapRouteData(
      routeId: 'teacher_route_04',
      routeName: 'Teacher/Staff (চৌমাথা)',
      color: const Color(0xFFD500F9), // Purple
      pathPoints: const [
        LatLng(22.7000, 90.3570), // Choumatha
        LatLng(22.6800, 90.3580), // Amtala
        LatLng(22.6610, 90.3545), // Tolghat
        LatLng(22.6581, 90.3552), // BU Campus
      ],
      keyStops: const [
        choumatha,
        amtalarMor,
        tolghat,
        buCampus,
      ],
    ),
  ];
}
