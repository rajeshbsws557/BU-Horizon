// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Device-level bus departure alarms.
//
// WHY THIS FILE LOOKS THE WAY IT DOES (bugs this fixes)
//  1. Permissions were requested inside `initialize()` and the results were
//     thrown away. On Android 13+ a denied POST_NOTIFICATIONS means
//     `zonedSchedule` succeeds silently and nothing ever rings — the user saw
//     "Alarm set" and heard nothing. [ensurePermissions] now prompts properly
//     and reports the real state so the UI can warn.
//
//     It deliberately does NOT gate scheduling. A first attempt at this threw
//     "enable the permission in Settings" whenever the notification switch
//     read false — but on Android 12 and below there IS no such permission
//     entry to enable (POST_NOTIFICATIONS only exists on 13+), so the alarm
//     became impossible to set on exactly the devices that needed no
//     permission at all. Scheduling always proceeds; missing switches are
//     surfaced as advice with a deep link to the screen that owns them.
//  2. No notification channel was ever created. On Android 8+ the *channel*
//     owns sound/importance, and once created its settings are immutable, so
//     the implicit channel created by the first (soundless, default-importance)
//     schedule permanently muted every later alarm. We now create the channel
//     up front, with the device ringtone on the alarm audio stream, under a
//     versioned id so shipping new audio settings actually takes effect.
//  3. It rang (at best) as a quiet notification blip. Real alarms need
//     `alarmClock` scheduling, `category: alarm`, a full-screen intent and
//     FLAG_INSISTENT so the sound loops until the user acts.
//  4. Notification ids came from `String.hashCode`, which Dart does not
//     guarantee to be stable across process restarts — so "Cancel Alarm"
//     could cancel nothing. Ids are now a deterministic FNV-1a hash and are
//     persisted alongside the alarm.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Small icon for every notification this app posts.
///
/// Must be a white-on-transparent silhouette: Android masks small icons by
/// their alpha channel and throws the colours away, so the old
/// `@mipmap/ic_launcher` was rendered as a featureless grey square.
const String kNotificationIcon = 'ic_stat_bus_alarm';

/// Always-present icon used when [kNotificationIcon] is missing from the build.
///
/// Ugly (a grey block) but guaranteed to resolve — see [kFallbackNotificationIcon]
/// usage in [BusAlarmService.initialize] for why that trade is worth making.
const String kFallbackNotificationIcon = '@mipmap/ic_launcher';

/// Android's *alias* for the user's ringtone.
///
/// Deliberately NOT handed to `setSound()` any more. This is an indirection
/// that only RingtoneManager understands; the notification service often can't
/// play it, which produced an alarm that vibrated in total silence. It is kept
/// solely as the last-resort fallback. [BusAlarmService.resolveAlarmSoundUri]
/// asks the platform for the concrete `content://media/...` URI instead.
const String kDeviceRingtoneUri = 'content://settings/system/ringtone';

/// Bumped whenever the channel's audio/importance settings change. Android
/// freezes a channel's settings at creation time, so a new id is the only way
/// to roll out new alarm behaviour to users who already have the old channel.
///
/// v3: the sound is now a real, playable media URI. Users who already had v2
/// are stuck with its unplayable sound until this id changes.
const String kBusAlarmChannelId = 'bu_horizon_bus_alarms_v3';

/// Silent channel for the "your alarm is set" receipt. Kept separate from the
/// alarm channel so the confirmation can never make a sound, and so muting one
/// doesn't mute the other.
const String kBusAlarmStatusChannelId = 'bu_horizon_bus_alarm_status';

/// Channel ids we've shipped before. Deleted on init so stale, silent channels
/// stop showing up in the system notification settings screen.
const List<String> _legacyChannelIds = <String>[
  'bu_horizon_bus_alarms',
  'bu_horizon_bus_alarms_v2',
];

/// `Notification.FLAG_INSISTENT` — loop the sound until the user dismisses it.
/// This is the difference between a one-shot "ding" and an actual alarm.
const int _flagInsistent = 4;

/// Channel to [MainActivity], used to open the system screens where the
/// notification / exact-alarm switches actually live.
const MethodChannel _appSettingsChannel =
    MethodChannel('bu_horizon/app_settings');

/// Why an alarm could not be scheduled, in terms the UI can act on.
enum AlarmFailureReason {
  /// Flutter Web has no `zonedSchedule` implementation.
  unsupportedPlatform,

  /// The plugin/platform rejected the schedule call.
  platformError,
}

/// Thrown by [BusAlarmService.scheduleBusAlarm] instead of failing silently.
class BusAlarmException implements Exception {
  final AlarmFailureReason reason;
  final String message;

  const BusAlarmException(this.reason, this.message);

  @override
  String toString() => message;
}

/// Snapshot of every OS permission this feature depends on.
class AlarmPermissionStatus {
  /// POST_NOTIFICATIONS (Android 13+) / alerts (iOS). Hard requirement.
  final bool notificationsGranted;

  /// SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM (Android 12+). Without it the
  /// alarm still fires, but the OS may batch it a few minutes late.
  final bool exactAlarmsGranted;

  const AlarmPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
  });

  /// True when the alarm will ring at (or extremely near) the exact minute.
  bool get isFullyGranted => notificationsGranted && exactAlarmsGranted;

  static const AlarmPermissionStatus granted = AlarmPermissionStatus(
    notificationsGranted: true,
    exactAlarmsGranted: true,
  );
}

/// Where a missing switch actually lives, so the UI can send the user there
/// instead of naming a permission that may not exist on their Android version.
enum AlarmSettingsTarget { notifications, exactAlarms }

/// Progressively simpler alarm payloads, tried in order until one is accepted.
///
/// Ringing loudly is the goal, but *some* reminder always beats a hard failure.
enum _AlarmPayloadVariant {
  /// Everything: full-screen intent, looping sound, device ringtone.
  full,

  /// Drops the full-screen intent (the most commonly refused extra).
  noFullScreen,

  /// Plain high-priority notification on the alarm channel.
  minimal,
}

class ScheduledBusAlarmInfo {
  final String id;
  final String routeName;
  final String departurePlace;
  final String tripTime;
  final String busName;
  final int leadMinutes;
  final String scheduledRingTimeIso;

  /// The OS notification id this alarm was scheduled under. Persisted so
  /// cancelling after a restart always targets the right pending alarm.
  final int? notificationId;

  ScheduledBusAlarmInfo({
    required this.id,
    required this.routeName,
    required this.departurePlace,
    required this.tripTime,
    required this.busName,
    required this.leadMinutes,
    required this.scheduledRingTimeIso,
    this.notificationId,
  });

  DateTime get scheduledRingTime => DateTime.parse(scheduledRingTimeIso);

  /// True once the ring time has passed (the alarm has already gone off).
  bool get hasElapsed => scheduledRingTime.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'routeName': routeName,
        'departurePlace': departurePlace,
        'tripTime': tripTime,
        'busName': busName,
        'leadMinutes': leadMinutes,
        'scheduledRingTimeIso': scheduledRingTimeIso,
        'notificationId': notificationId,
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
        notificationId: json['notificationId'] as int?,
      );
}

class BusAlarmService {
  static final BusAlarmService instance = BusAlarmService._internal();
  BusAlarmService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const String _prefKey = 'bu_horizon_scheduled_bus_alarms';

  /// Concrete, playable ringtone URI resolved from the platform. Null until
  /// [initialize] runs, or when the device offers nothing usable.
  String? _alarmSoundUri;

  /// The small icon actually used, after confirming it exists in this build.
  ///
  /// The custom icon is referenced only as a Dart string, so R8's resource
  /// shrinker silently dropped it from the release APK — and the plugin then
  /// refused to schedule ANY alarm ("The resource ic_stat_bus_alarm could not
  /// be found"). res/raw/keep.xml stops the shrinking; this field makes sure a
  /// missing icon can only ever cost us a nice glyph, never the alarm itself.
  String _notificationIcon = kFallbackNotificationIcon;

  /// Sound for the alarm channel/notification, or null to let the plugin fall
  /// back to the platform default (which is still audible).
  UriAndroidNotificationSound? get _alarmSound {
    final uri = _alarmSoundUri;
    return uri == null ? null : UriAndroidNotificationSound(uri);
  }

  /// Whether a drawable of this name exists in the installed app.
  ///
  /// Defaults to false when it can't be determined, so we fall back to the
  /// icon that is guaranteed to exist rather than risk breaking scheduling.
  Future<bool> _hasDrawable(String name) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _appSettingsChannel.invokeMethod<bool>(
            'hasDrawable',
            {'name': name},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Could not check drawable "$name": $e');
      return false;
    }
  }

  /// Asks Android for a real `content://media/...` ringtone URI.
  ///
  /// The channel used to be given `content://settings/system/ringtone`, which
  /// is a RingtoneManager *alias* rather than playable media. The notification
  /// service silently failed to play it, so the alarm vibrated with no sound.
  Future<String?> resolveAlarmSoundUri() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _appSettingsChannel.invokeMethod<String>(
        'resolveAlarmSoundUri',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Could not resolve ringtone URI: $e');
      return null;
    }
  }

  /// Scheduled OS alarms are a native-only capability. Flutter Web has no
  /// equivalent to `zonedSchedule`, so the UI uses this to show a clear
  /// "use the mobile app" message instead of silently failing.
  bool get isSupported => !kIsWeb;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      defaultTargetPlatform == TargetPlatform.android
          ? _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          : null;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz_data.initializeTimeZones();
    // `tz.local` defaults to UTC until a location is set. Anchor it to the
    // device's real UTC offset so the ring time we compute in local wall-clock
    // terms maps to the correct absolute instant. Bangladesh is UTC+6 with no
    // DST, so a fixed-offset match is accurate for BU's users.
    _configureLocalTimeZone();

    // Prefer the monochrome silhouette (the colour launcher icon is alpha-
    // masked into a grey square), but only if it survived into this build.
    _notificationIcon = await _hasDrawable(kNotificationIcon)
        ? kNotificationIcon
        : kFallbackNotificationIcon;
    if (_notificationIcon != kNotificationIcon) {
      debugPrint(
        'Notification icon "$kNotificationIcon" is missing from this build; '
        'falling back to $kFallbackNotificationIcon.',
      );
    }
    final androidSettings = AndroidInitializationSettings(_notificationIcon);
    // Don't request iOS permissions during init — we ask explicitly (and read
    // the answer) in [ensurePermissions] so a denial is visible to the UI.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
      // Must resolve BEFORE the channel is created: a channel's sound is
      // frozen at creation time and can never be changed afterwards.
      _alarmSoundUri = await resolveAlarmSoundUri();
      debugPrint('Alarm sound URI resolved to: $_alarmSoundUri');
      await _createAlarmChannel();
    } on MissingPluginException {
      // Unit-test / unsupported host: leave uninitialized but don't crash.
      return;
    } on PlatformException catch (e) {
      debugPrint('BusAlarmService init failed: $e');
      return;
    }

    _initialized = true;
  }

  /// Creates the high-importance alarm channel that actually makes noise.
  ///
  /// Sound + importance live on the channel on Android 8+, and are frozen once
  /// the channel exists — hence the versioned [kBusAlarmChannelId] and the
  /// cleanup of [_legacyChannelIds].
  Future<void> _createAlarmChannel() async {
    final android = _android;
    if (android == null) return;

    for (final legacyId in _legacyChannelIds) {
      try {
        await android.deleteNotificationChannel(legacyId);
      } catch (_) {
        // Channel may not exist on a fresh install — nothing to clean up.
      }
    }

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        kBusAlarmChannelId,
        'Bus Departure Alarms',
        description:
            'Rings at full volume before your university bus leaves, even when '
            'the app is closed.',
        importance: Importance.max,
        playSound: true,
        // A concrete media URI. Passing the `content://settings/system/...`
        // alias here is what left the alarm vibrating but silent — the
        // notification service can't play that indirection. Null falls back to
        // the platform default, which is audible.
        sound: _alarmSound,
        // Route through the alarm stream so it is audible even in silent /
        // vibrate profiles and ignores the notification volume slider.
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // Receipts are informational only — never a sound, never a vibration.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        kBusAlarmStatusChannelId,
        'Bus Alarm Confirmations',
        description:
            'Silent reminder showing which bus alarm is currently set.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// Notification id for the receipt that pairs with a given alarm.
  ///
  /// Offset into a disjoint range so a receipt can never collide with (and
  /// therefore silently replace) a real alarm notification.
  int _statusIdFor(String tripId) =>
      (notificationIdFor(tripId) % 1000000) + 1000000;

  /// Posts a silent, dismissible "alarm is set" receipt.
  ///
  /// Until now the only feedback was an in-app toast that vanished in seconds,
  /// so there was no way to confirm an alarm was actually armed. Best-effort:
  /// a failure here must never fail the alarm itself.
  Future<void> _showAlarmSetReceipt(ScheduledBusAlarmInfo alarm) async {
    if (kIsWeb) return;

    final ringsAt = alarm.scheduledRingTime;
    final hour12 = ringsAt.hour % 12 == 0 ? 12 : ringsAt.hour % 12;
    final minute = ringsAt.minute.toString().padLeft(2, '0');
    final meridiem = ringsAt.hour < 12 ? 'AM' : 'PM';

    try {
      await _notificationsPlugin.show(
        _statusIdFor(alarm.id),
        '⏰ Bus alarm set · ${alarm.tripTime}',
        'Rings at $hour12:$minute $meridiem — '
            '${alarm.leadMinutes} min before ${alarm.busName} '
            'leaves ${alarm.departurePlace}.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            kBusAlarmStatusChannelId,
            'Bus Alarm Confirmations',
            channelDescription:
                'Silent reminder showing which bus alarm is currently set.',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            icon: _notificationIcon,
            // Sticks around as a visible record that the alarm is armed, but
            // stays swipe-away-able.
            ongoing: false,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          ),
        ),
      );
    } on MissingPluginException {
      // Test host — nothing to show.
    } on PlatformException catch (e) {
      debugPrint('Could not post alarm receipt: $e');
    }
  }

  /// Picks a timezone whose current UTC offset matches the device, so
  /// wall-clock ring times resolve to the right absolute moment.
  void _configureLocalTimeZone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      // Fast path for BU's region (UTC+6, Asia/Dhaka).
      if (offset == const Duration(hours: 6)) {
        tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
        return;
      }
      // General fallback: find any location matching the current offset.
      for (final location in tz.timeZoneDatabase.locations.values) {
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (_) {
      // Leave tz.local as-is; scheduling below still uses an absolute instant.
    }
  }

  /// Reports what the alarm is allowed to do, prompting where a prompt exists.
  ///
  /// Each probe is isolated: the plugin rejects a request with
  /// `permissionRequestInProgress` if another is still on screen, and one such
  /// failure must not poison the whole status (nor be mistaken for a denial).
  ///
  /// Unknown state is treated as *allowed*. This reads optimistically on
  /// purpose — a wrong "granted" merely means the alarm is attempted anyway,
  /// while a wrong "denied" used to block the feature outright.
  Future<AlarmPermissionStatus> ensurePermissions({bool prompt = true}) async {
    if (kIsWeb) {
      return const AlarmPermissionStatus(
        notificationsGranted: false,
        exactAlarmsGranted: false,
      );
    }

    await initialize();

    final android = _android;
    if (android != null) {
      // 1. Can notifications be shown at all?
      //    On Android 13+ this maps to POST_NOTIFICATIONS; below that it's the
      //    app's notification switch, which no in-app prompt can change — only
      //    the settings screen [openNotificationSettings] opens.
      var notificationsGranted =
          await _probe(() => android.areNotificationsEnabled()) ?? true;
      if (!notificationsGranted && prompt) {
        await _probe(() => android.requestNotificationsPermission());
        // Re-read rather than trusting the request's return value: on Android
        // < 13 it only echoes the switch and reports a "denial" that the user
        // was never actually asked about.
        notificationsGranted =
            await _probe(() => android.areNotificationsEnabled()) ?? true;
      }

      // 2. Exact alarms (Android 12+). Missing this only delays the alarm.
      var exactGranted =
          await _probe(() => android.canScheduleExactNotifications()) ?? true;
      if (!exactGranted && prompt) {
        await _probe(() => android.requestExactAlarmsPermission());
        exactGranted =
            await _probe(() => android.canScheduleExactNotifications()) ?? true;
      }

      // 3. Full-screen intent (Android 14+) so the alarm can take over the
      //    lock screen like a clock alarm. Best-effort: never fatal.
      if (prompt) {
        await _probe(() => android.requestFullScreenIntentPermission());
      }

      return AlarmPermissionStatus(
        notificationsGranted: notificationsGranted,
        exactAlarmsGranted: exactGranted,
      );
    }

    // iOS / macOS: a single alert+sound grant covers everything.
    final darwin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      try {
        final granted = await darwin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            ) ??
            false;
        return AlarmPermissionStatus(
          notificationsGranted: granted,
          exactAlarmsGranted: granted,
        );
      } on MissingPluginException {
        return AlarmPermissionStatus.granted;
      }
    }

    return AlarmPermissionStatus.granted;
  }

  /// Runs a single platform permission call, swallowing the failures that mean
  /// "couldn't ask right now" rather than "the user said no".
  Future<bool?> _probe(Future<bool?> Function() call) async {
    try {
      return await call();
    } on MissingPluginException {
      return null; // Test host / platform without the plugin.
    } on PlatformException catch (e) {
      // `permissionRequestInProgress` fires when another prompt is still up.
      debugPrint('Alarm permission probe skipped (${e.code}): $e');
      return null;
    }
  }

  /// Opens the system screen that owns a given switch.
  ///
  /// The alarm's blocker is usually the app's *Notifications* toggle, which on
  /// Android 12 and below has no entry under "Permissions" at all — hence a
  /// direct deep link instead of instructions to go hunting. Returns false if
  /// the ROM has no such screen, so the caller can fall back to text.
  Future<bool> openAlarmSettings(AlarmSettingsTarget target) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final method = switch (target) {
        AlarmSettingsTarget.notifications => 'openNotificationSettings',
        AlarmSettingsTarget.exactAlarms => 'openExactAlarmSettings',
      };
      return await _appSettingsChannel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Could not open alarm settings: $e');
      return false;
    }
  }

  /// Builds the notification payload for a given fallback step.
  AndroidNotificationDetails _androidDetailsFor(_AlarmPayloadVariant variant) {
    // Channel id/description stay constant; only the extras that a device can
    // reject are stepped down.
    return AndroidNotificationDetails(
      kBusAlarmChannelId,
      'Bus Departure Alarms',
      channelDescription:
          'Rings at full volume before your university bus leaves, even when '
          'the app is closed.',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      // Sound also lives on the channel, so dropping it here still leaves the
      // alarm audible on Android 8+.
      sound: variant == _AlarmPayloadVariant.minimal ? null : _alarmSound,
      // Verified to exist (see [_notificationIcon]); passing a name the build
      // doesn't contain makes the plugin reject the whole schedule.
      icon: _notificationIcon,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      // Needs USE_FULL_SCREEN_INTENT and can be refused outright on 14+.
      fullScreenIntent: variant == _AlarmPayloadVariant.full,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      // FLAG_INSISTENT loops the sound until dismissed — the thing that makes
      // it an alarm rather than a blip.
      additionalFlags: variant == _AlarmPayloadVariant.minimal
          ? null
          : Int32List.fromList(<int>[_flagInsistent]),
      ticker: 'BU Bus Departure Alarm',
      // An alarm you can swipe away by accident isn't an alarm.
      autoCancel: false,
    );
  }

  /// Deterministic 31-bit id for a trip string.
  ///
  /// Deliberately NOT `String.hashCode`: Dart makes no cross-run stability
  /// promise there, so an id computed after a restart could differ from the one
  /// the alarm was scheduled under, leaving "Cancel Alarm" a no-op. FNV-1a is
  /// fixed by its spec, so the same trip always maps to the same id.
  int notificationIdFor(String idStr) {
    var hash = 0x811c9dc5; // FNV-1a 32-bit offset basis
    for (final unit in idStr.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, wrapped to 32 bits
    }
    // Android notification ids are Java ints: keep it positive and in range.
    return hash & 0x7FFFFFFF;
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
  ///
  /// Throws [BusAlarmException] only when the platform genuinely refuses (or on
  /// web, where scheduling doesn't exist). Missing permissions never block it.
  Future<ScheduledBusAlarmInfo> scheduleBusAlarm({
    required String tripId,
    required String routeName,
    required String departurePlace,
    required String tripTime,
    required String busName,
    required int leadMinutes,
  }) async {
    if (kIsWeb) {
      throw const BusAlarmException(
        AlarmFailureReason.unsupportedPlatform,
        'Bus alarms ring through your phone, so they need the BU Horizon '
        'mobile app. Open it on Android or iOS to set this alarm.',
      );
    }
    await initialize();

    // Prompt for anything missing, but NEVER refuse to schedule on the result.
    //
    // An earlier version threw here when `notificationsGranted` was false. On
    // Android 12 and below that flag is just "is the notification switch on",
    // and POST_NOTIFICATIONS doesn't exist as a permission at all — so the app
    // told users to grant a permission their phone doesn't have, and refused to
    // set an alarm that would very likely have worked. The alarm is always
    // registered now; the UI separately surfaces any switch worth turning on.
    final permissions = await ensurePermissions();

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

    final notificationId = notificationIdFor(tripId);

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final title = '🚌 Bus Alarm: $busName ($tripTime)';
    final body =
        'Leaves from $departurePlace in $leadMinutes mins! ($routeName)';

    final tzRingTime = tz.TZDateTime.from(finalRingTime, tz.local);

    // Try richest-first, then degrade. Two axes can each be rejected by a given
    // device, so both are stepped down independently:
    //
    //  * schedule mode — `alarmClock` is the strongest (survives Doze, same
    //    primitive the Clock app uses) but needs exact-alarm permission;
    //  * notification payload — full-screen intent, FLAG_INSISTENT and a custom
    //    sound URI are all things an OEM ROM can throw on.
    //
    // An earlier version varied only the mode while reusing one payload, so if
    // the payload was what the device disliked, all three attempts failed
    // identically and the user simply couldn't set an alarm. A plain reminder
    // is far better than none.
    final modes = <AndroidScheduleMode>[
      if (permissions.exactAlarmsGranted) AndroidScheduleMode.alarmClock,
      if (permissions.exactAlarmsGranted)
        AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    PlatformException? lastPlatformError;
    var scheduled = false;

    outer:
    for (final variant in _AlarmPayloadVariant.values) {
      for (final mode in modes) {
        try {
          await _notificationsPlugin.zonedSchedule(
            notificationId,
            title,
            body,
            tzRingTime,
            NotificationDetails(
              android: _androidDetailsFor(variant),
              iOS: iosDetails,
            ),
            androidScheduleMode: mode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          scheduled = true;
          if (variant != _AlarmPayloadVariant.full) {
            debugPrint('Alarm scheduled with reduced payload: ${variant.name}');
          }
          break outer;
        } on PlatformException catch (e) {
          // `exact_alarms_not_permitted` -> next mode. A bare `error` code is
          // Flutter wrapping an uncaught Java exception, where e.message holds
          // the only useful detail — hence it's logged and reported verbatim.
          debugPrint(
            'Alarm schedule failed [${variant.name}/$mode] '
            'code=${e.code} message=${e.message}',
          );
          lastPlatformError = e;
        } on MissingPluginException {
          // Unit-test host: record the alarm so state-level tests still pass.
          break outer;
        }
      }
    }

    if (!scheduled && lastPlatformError != null) {
      // Report what the platform actually said. The previous message printed
      // only the error code — which for wrapped exceptions is the literal
      // string "error" — producing the useless "refused to schedule (error)"
      // and pointing at an "alarm permission" that may not even exist.
      final detail = lastPlatformError.message?.trim();
      throw BusAlarmException(
        AlarmFailureReason.platformError,
        detail == null || detail.isEmpty
            ? 'Your phone would not schedule this alarm (${lastPlatformError.code}).'
            : 'Your phone would not schedule this alarm: $detail',
      );
    }

    final alarmInfo = ScheduledBusAlarmInfo(
      id: tripId,
      routeName: routeName,
      departurePlace: departurePlace,
      tripTime: tripTime,
      busName: busName,
      leadMinutes: leadMinutes,
      scheduledRingTimeIso: finalRingTime.toIso8601String(),
      notificationId: notificationId,
    );

    await _saveAlarmToPrefs(alarmInfo);
    // Visible proof the alarm exists, surviving long after the in-app toast.
    await _showAlarmSetReceipt(alarmInfo);
    return alarmInfo;
  }

  /// Cancels an existing scheduled bus alarm.
  Future<void> cancelBusAlarm(String tripId) async {
    await initialize();

    // Prefer the id the alarm was actually scheduled under; fall back to the
    // derived one for alarms saved before ids were persisted.
    final existing = await getAlarmForTrip(tripId);
    final notificationId = existing?.notificationId ?? notificationIdFor(tripId);

    try {
      await _notificationsPlugin.cancel(notificationId);
      // Clear the receipt too, or the user is left looking at a confirmation
      // for an alarm that no longer exists.
      await _notificationsPlugin.cancel(_statusIdFor(tripId));
    } on MissingPluginException {
      // Nothing scheduled on this host; still clear our own bookkeeping.
    } on PlatformException catch (e) {
      debugPrint('Cancel failed for $tripId: $e');
    }
    await _removeAlarmFromPrefs(tripId);
  }

  /// Retrieves all active scheduled bus alarms saved in preferences.
  Future<List<ScheduledBusAlarmInfo>> getScheduledAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((item) =>
              ScheduledBusAlarmInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Checks if an alarm is currently scheduled for a specific trip.
  Future<ScheduledBusAlarmInfo?> getAlarmForTrip(String tripId) async {
    final alarms = await getScheduledAlarms();
    for (final alarm in alarms) {
      if (alarm.id == tripId) return alarm;
    }
    return null;
  }

  /// Drops alarms whose ring time has passed and re-arms any still-future alarm
  /// the OS has forgotten (app update, force stop, or a reboot that outran the
  /// boot receiver). Call once on app start; failures are non-fatal.
  Future<void> restorePendingAlarms() async {
    if (kIsWeb) return;
    await initialize();

    final stored = await getScheduledAlarms();
    if (stored.isEmpty) return;

    final now = DateTime.now();
    final future =
        stored.where((a) => a.scheduledRingTime.isAfter(now)).toList();

    // Prune elapsed alarms so the picker doesn't show yesterday's reminder as
    // still active, and clear their now-meaningless receipts.
    if (future.length != stored.length) {
      final elapsed = stored.where((a) => !a.scheduledRingTime.isAfter(now));
      for (final a in elapsed) {
        try {
          await _notificationsPlugin.cancel(_statusIdFor(a.id));
        } catch (_) {
          // Best-effort cleanup; never block startup on it.
        }
      }
      await _writeAlarms(future);
    }
    if (future.isEmpty) return;

    Set<int> pendingIds;
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      pendingIds = pending.map((p) => p.id).toSet();
    } on MissingPluginException {
      return;
    } on PlatformException catch (e) {
      debugPrint('Could not read pending alarms: $e');
      return;
    }

    for (final alarm in future) {
      final id = alarm.notificationId ?? notificationIdFor(alarm.id);
      if (pendingIds.contains(id)) continue;
      try {
        await scheduleBusAlarm(
          tripId: alarm.id,
          routeName: alarm.routeName,
          departurePlace: alarm.departurePlace,
          tripTime: alarm.tripTime,
          busName: alarm.busName,
          leadMinutes: alarm.leadMinutes,
        );
      } catch (e) {
        debugPrint('Could not re-arm alarm ${alarm.id}: $e');
      }
    }
  }

  Future<void> _saveAlarmToPrefs(ScheduledBusAlarmInfo alarm) async {
    final alarms = await getScheduledAlarms();
    alarms.removeWhere((a) => a.id == alarm.id);
    alarms.add(alarm);
    await _writeAlarms(alarms);
  }

  Future<void> _removeAlarmFromPrefs(String tripId) async {
    final alarms = await getScheduledAlarms();
    alarms.removeWhere((a) => a.id == tripId);
    await _writeAlarms(alarms);
  }

  Future<void> _writeAlarms(List<ScheduledBusAlarmInfo> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = alarms.map((a) => a.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(jsonList));
  }
}
