// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Static demo content. Swap these for API/DB calls when wiring a backend.
class SampleData {
  SampleData._();

  static final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

  static const String studentName = 'Rajesh Biswas';
  static const String studentId = 'CSE-2021-047';
  static const String studentDept = 'CSE Department, 3rd Semester';
  static const String studentEmail = 'rajeshbiswas@bu.edu.bd';


  static const List<QuickAction> quickActions = [
    QuickAction(
        title: 'Bus Schedule',
        subtitle: 'View bus timing & set alarm',
        icon: Icons.directions_bus_rounded,
        color: AppColors.primary,
        route: '/bus',),
    QuickAction(
        title: 'Class Notices',
        subtitle: 'Stay updated',
        icon: Icons.campaign_rounded,
        color: AppColors.accentCyan,
        route: '/notices',),
    QuickAction(
        title: 'People Search',
        subtitle: 'Find anyone in campus',
        icon: Icons.group_rounded,
        color: AppColors.purple,
        route: '/people',),
    QuickAction(
        title: 'Blood Help',
        subtitle: 'Request or offer blood',
        icon: Icons.water_drop_rounded,
        color: AppColors.danger,
        route: '/blood',),
    QuickAction(
        title: 'Lost & Found',
        subtitle: 'Report or find items',
        icon: Icons.inventory_2_rounded,
        color: AppColors.warning,
        route: '/lost-found',),
    QuickAction(
        title: 'Attendance',
        subtitle: 'Mark & track attendance',
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        route: '/attendance',),
  ];

  static List<BusRoute> busRoutes() => [
        const BusRoute(name: 'Mirpur Route', window: '7:30 AM - 10:30 PM', frequency: 'Every 20 min', nextBus: '9:30 AM', favorite: true),
        const BusRoute(name: 'Uttara Route', window: '7:00 AM - 10:00 PM', frequency: 'Every 25 min', nextBus: '9:25 AM', favorite: true),
        const BusRoute(name: 'Dhanmondi Route', window: '7:15 AM - 10:15 PM', frequency: 'Every 30 min', nextBus: '9:45 AM'),
        const BusRoute(name: 'Savar Route', window: '6:45 AM - 9:45 PM', frequency: 'Every 30 min', nextBus: '9:15 AM'),
        const BusRoute(name: 'Gabtoli Route', window: '7:00 AM - 10:00 PM', frequency: 'Every 40 min', nextBus: '9:35 AM'),
      ];

  static const List<ClassNotice> notices = [
    ClassNotice(title: 'CSE Department', subtitle: 'Class canceled today at 2 PM', time: '10:30 AM', category: NoticeCategory.department, icon: Icons.notifications_active_rounded, color: AppColors.primary),
    ClassNotice(title: 'Exam Notice', subtitle: 'Midterm exam routine published', time: 'Yesterday', category: NoticeCategory.academic, icon: Icons.edit_document, color: AppColors.warning),
    ClassNotice(title: 'EEE Department', subtitle: 'Project submission deadline extended', time: 'Yesterday', category: NoticeCategory.department, icon: Icons.folder_copy_rounded, color: AppColors.accentCyan),
    ClassNotice(title: 'Seminar', subtitle: 'AI in Modern World', time: '2 days ago', category: NoticeCategory.events, icon: Icons.mic_rounded, color: AppColors.danger),
    ClassNotice(title: 'Library Notice', subtitle: 'Library will remain closed on Sunday', time: '3 days ago', category: NoticeCategory.academic, icon: Icons.local_library_rounded, color: AppColors.purple),
    ClassNotice(title: 'Math Department', subtitle: 'Extra class on Calculus', time: '3 days ago', category: NoticeCategory.department, icon: Icons.functions_rounded, color: AppColors.primary),
    ClassNotice(title: 'Workshop', subtitle: 'Web Development Workshop', time: '5 days ago', category: NoticeCategory.events, icon: Icons.build_rounded, color: AppColors.warning),
  ];

  static const List<Person> people = [
    Person(name: 'Rajib Hasan', department: 'Chemistry Department', email: 'rajib.hasan@bu.edu.bd'),
    Person(name: 'Nusrat Jahan', department: 'CSE Department', email: 'nusrat.jahan@bu.edu.bd'),
    Person(name: 'Shakib Ahmed', department: 'EEE Department', email: 'shakib.ahmed@bu.edu.bd'),
    Person(name: 'Fahim Rahman', department: 'Law Department', email: 'fahim.rahman@bu.edu.bd'),
    Person(name: 'Tania Islam', department: 'Architecture Department', email: 'tania.islam@bu.edu.bd'),
    Person(name: 'Tanvir Hasan', department: 'Physics Department', email: 'tanvir.hasan@bu.edu.bd'),
    Person(name: 'Mehedi Hasan', department: 'English Department', email: 'mehedi.hasan@bu.edu.bd'),
  ];

  static const BloodNeed urgentBloodNeed = BloodNeed(
    units: 3,
    group: BloodGroup.bPositive,
    contact: '01712-345678',
    location: 'Shaheed Suhrawardy Medical',
    time: '2 hrs ago',
  );

  static const List<BloodRequest> bloodRequests = [
    BloodRequest(group: BloodGroup.bPositive, location: 'Mirpur Campus', time: '1 hr ago'),
    BloodRequest(group: BloodGroup.oNegative, location: 'Ibrahim Medical', time: '3 hrs ago'),
    BloodRequest(group: BloodGroup.abPositive, location: 'BSMMU', time: '5 hrs ago'),
    BloodRequest(group: BloodGroup.aPositive, location: 'Labaid Hospital', time: '6 hrs ago'),
    BloodRequest(group: BloodGroup.bNegative, location: 'United Hospital', time: '1 day ago'),
  ];

  static const List<LostFoundItem> lostFound = [
    LostFoundItem(title: 'Lost: Wallet', description: 'Black wallet with ID cards', location: 'Science Building', time: 'Today, 10:30 AM', isLost: true, icon: Icons.account_balance_wallet_rounded),
    LostFoundItem(title: 'Lost: Smart Watch', description: 'Black strap smart watch', location: 'Cafeteria', time: 'Yesterday, 4:20 PM', isLost: true, icon: Icons.watch_rounded),
    LostFoundItem(title: 'Found: Key', description: 'Single key with keychain', location: 'Library', time: '2 days ago', isLost: false, icon: Icons.key_rounded),
    LostFoundItem(title: 'Found: ID Card', description: 'ID card found near Main Gate', location: 'Main Gate', time: '2 days ago', isLost: false, icon: Icons.badge_rounded),
    LostFoundItem(title: 'Lost: Backpack', description: 'Black backpack', location: 'Bus Stand', time: '3 days ago', isLost: true, icon: Icons.backpack_rounded),
  ];

  static const List<AttendanceClass> todayAttendance = [
    AttendanceClass(subject: 'Data Structures', time: '9:00 AM - 10:00 AM', status: AttendanceStatus.present),
    AttendanceClass(subject: 'Discrete Math', time: '10:15 AM - 11:15 AM', status: AttendanceStatus.present),
    AttendanceClass(subject: 'Digital Logic', time: '11:30 AM - 12:30 PM', status: AttendanceStatus.present),
    AttendanceClass(subject: 'Physics', time: '1:30 PM - 2:30 PM', status: AttendanceStatus.upcoming),
  ];

  static const List<AlertItem> alerts = [
    AlertItem(title: 'Bus Delay', subtitle: 'Mirpur Route bus delayed by 15 mins', time: '10:20 AM', type: AlertType.bus),
    AlertItem(title: 'Class Notice', subtitle: 'CSE class rescheduled to 3 PM', time: 'Yesterday', type: AlertType.notice),
    AlertItem(title: 'Exam Notice', subtitle: 'Midterm exam on June 2', time: 'Yesterday', type: AlertType.exam),
    AlertItem(title: 'Event', subtitle: 'Tech Fest 2024 registration open', time: '2 days ago', type: AlertType.event),
    AlertItem(title: 'Library Notice', subtitle: 'Digital section maintenance', time: '3 days ago', type: AlertType.library),
    AlertItem(title: 'Lost & Found', subtitle: 'A wallet has been found in library', time: '3 days ago', type: AlertType.lostFound),
  ];
}
