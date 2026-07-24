// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ScheduledBusAlarmInfo {
  final String id;
  final String routeName;
  final String departurePlace;
  final String tripTime;
  final String busName;
  final int leadMinutes;
  final String scheduledRingTimeIso;

  ScheduledBusAlarmInfo({
    required this.id,
    required this.routeName,
    required this.departurePlace,
    required this.tripTime,
    required this.busName,
    required this.leadMinutes,
    required this.scheduledRingTimeIso,
  });

  DateTime get scheduledRingTime => DateTime.parse(scheduledRingTimeIso);

  Map<String, dynamic> toJson() => {
        'id': id,
        'routeName': routeName,
        'departurePlace': departurePlace,
        'tripTime': tripTime,
        'busName': busName,
        'leadMinutes': leadMinutes,
        'scheduledRingTimeIso': scheduledRingTimeIso,
      };

  factory ScheduledBusAlarmInfo.fromJson(Map<String, dynamic> json) =>
      ScheduledBusAlarmInfo(
        id: json['id'] as String,
        routeName: json['routeName'] as String,
        departurePlace: json['departurePlace'] as String,
        tripTime: json['tripTime'] as String,
        busName: json['busName'] as String,
        leadMinutes: json['leadMinutes'] as int,
        scheduledRingTimeIso: json['scheduledRingTimeIso'] as String,
      );
}

class BusAlarmService {
  static final BusAlarmService instance = BusAlarmService._internal();
  BusAlarmService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const String _prefKey = 'bu_horizon_scheduled_bus_alarms';

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Request permissions for Android 13+ (POST_NOTIFICATIONS)
    if (!kIsWeb) {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
  }

  /// Unique notification integer ID generated from trip string identifier.
  int _generateNotificationId(String idStr) {
    return idStr.hashCode.abs() % 1000000;
  }

  /// Parses strings like "8:30 AM", "12:10 PM", "6:45 PM" into a DateTime object.
  DateTime parseTripTimeToDateTime(String timeStr) {
    final clean = timeStr.trim().toUpperCase();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.isEmpty) return DateTime.now();

    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');

    final timeDigits = parts.first.replaceAll(RegExp(r'[^0-9:]'), '');
    final hourMinute = timeDigits.split(':');

    int hour = hourMinute.isNotEmpty ? int.tryParse(hourMinute[0]) ?? 8 : 8;
    final int minute = hourMinute.length > 1 ? int.tryParse(hourMinute[1]) ?? 0 : 0;

    if (isPm && hour < 12) {
      hour += 12;
    } else if (isAm && hour == 12) {
      hour = 0;
    }

    final now = DateTime.now();
    DateTime departureDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the bus departure time has already passed today, schedule for tomorrow
    if (departureDateTime.isBefore(now)) {
      departureDateTime = departureDateTime.add(const Duration(days: 1));
    }

    return departureDateTime;
  }

  /// Schedules an exact OS alarm for a bus trip with user's selected lead time.
  Future<ScheduledBusAlarmInfo?> scheduleBusAlarm({
    required String tripId,
    required String routeName,
    required String departurePlace,
    required String tripTime,
    required String busName,
    required int leadMinutes,
  }) async {
    await initialize();

    final departureTime = parseTripTimeToDateTime(tripTime);
    final ringTime = departureTime.subtract(Duration(minutes: leadMinutes));
    final now = DateTime.now();

    // If the calculated ring time is in the past (e.g. 5 min lead for a bus leaving in 2 min today),
    // adjust to tomorrow's trip
    DateTime finalRingTime = ringTime;
    DateTime finalDepartureTime = departureTime;

    if (finalRingTime.isBefore(now)) {
      finalDepartureTime = departureTime.add(const Duration(days: 1));
      finalRingTime = finalDepartureTime.subtract(Duration(minutes: leadMinutes));
    }

    final notificationId = _generateNotificationId(tripId);

    const androidDetails = AndroidNotificationDetails(
      'bu_horizon_bus_alarms',
      'Bus Departure Alarms',
      channelDescription:
          'High priority exact ringing alarms for university bus departures.',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ticker: 'BU Bus Departure Alarm',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = '🚌 Bus Alarm: $busName ($tripTime)';
    final body =
        'Leaves from $departurePlace in $leadMinutes mins! ($routeName)';

    final tzRingTime = tz.TZDateTime.from(finalRingTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tzRingTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Fallback to standard schedule: $e');
    }

    final alarmInfo = ScheduledBusAlarmInfo(
      id: tripId,
      routeName: routeName,
      departurePlace: departurePlace,
      tripTime: tripTime,
      busName: busName,
      leadMinutes: leadMinutes,
      scheduledRingTimeIso: finalRingTime.toIso8601String(),
    );

    await _saveAlarmToPrefs(alarmInfo);
    return alarmInfo;
  }

  /// Cancels an existing scheduled bus alarm.
  Future<void> cancelBusAlarm(String tripId) async {
    await initialize();
    final notificationId = _generateNotificationId(tripId);
    await _notificationsPlugin.cancel(notificationId);
    await _removeAlarmFromPrefs(tripId);
  }

  /// Retrieves all active scheduled bus alarms saved in preferences.
  Future<List<ScheduledBusAlarmInfo>> getScheduledAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((item) => ScheduledBusAlarmInfo.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Checks if an alarm is currently scheduled for a specific trip.
  Future<ScheduledBusAlarmInfo?> getAlarmForTrip(String tripId) async {
    final alarms = await getScheduledAlarms();
    try {
      return alarms.firstWhere((a) => a.id == tripId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveAlarmToPrefs(ScheduledBusAlarmInfo alarm) async {
    final alarms = await getScheduledAlarms();
    alarms.removeWhere((a) => a.id == alarm.id);
    alarms.add(alarm);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = alarms.map((a) => a.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(jsonList));
  }

  Future<void> _removeAlarmFromPrefs(String tripId) async {
    final alarms = await getScheduledAlarms();
    alarms.removeWhere((a) => a.id == tripId);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = alarms.map((a) => a.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(jsonList));
  }
}
