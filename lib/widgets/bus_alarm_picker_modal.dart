// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/university_bus_schedule_data.dart';
import '../services/bus_alarm_service.dart';
import '../theme/app_theme.dart';


class BusAlarmPickerModal extends StatefulWidget {
  final String tripId;
  final String routeName;
  final String departurePlace;
  final String tripTime;
  final String busName;

  /// Days the trip runs, so the alarm lands on a date the bus actually leaves.
  final ServiceDays serviceDays;
  final VoidCallback? onAlarmUpdated;

  const BusAlarmPickerModal({
    super.key,
    required this.tripId,
    required this.routeName,
    required this.departurePlace,
    required this.tripTime,
    required this.busName,
    this.serviceDays = ServiceDays.daily,
    this.onAlarmUpdated,
  });

  @override
  State<BusAlarmPickerModal> createState() => _BusAlarmPickerModalState();
}

class _BusAlarmPickerModalState extends State<BusAlarmPickerModal>
    with WidgetsBindingObserver {
  int _selectedLeadMinutes = 15; // Default lead time: 15 minutes before
  DateTime? _manualRingTimeOverride;
  ScheduledBusAlarmInfo? _existingAlarm;
  AlarmPermissionStatus? _permissions;
  bool _loading = true;
  bool _isSaving = false;

  final List<int> _presetLeadTimes = [5, 10, 15, 30, 45, 60, 120];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have just flipped the switch in system Settings. Re-read on
    // return (without re-prompting) so the warning disappears by itself.
    if (state == AppLifecycleState.resumed) {
      _recheckPermissions(prompt: false);
    }
  }

  /// Loads any existing alarm *and* asks for the OS permissions the alarm
  /// needs. Opening this sheet is the natural moment to prompt: the user has
  /// just said "I want an alarm", so the system dialog has obvious context.
  /// Previously nothing was ever requested here, so on Android 13+ the alarm
  /// was scheduled into a void and simply never rang.
  Future<void> _initialize() async {
    final alarm = await BusAlarmService.instance.getAlarmForTrip(widget.tripId);
    if (mounted) {
      setState(() {
        _existingAlarm = alarm;
        if (alarm != null) {
          _selectedLeadMinutes = alarm.leadMinutes;
          _manualRingTimeOverride = alarm.scheduledRingTime;
        }
        _loading = false;
      });
    }

    if (kIsWeb) return;
    final permissions = await BusAlarmService.instance.ensurePermissions();
    if (!mounted) return;
    setState(() => _permissions = permissions);
  }

  /// Refreshes the banner. Pass `prompt: false` for a silent status read (e.g.
  /// when coming back from Settings) so the user isn't re-prompted.
  Future<void> _recheckPermissions({bool prompt = true}) async {
    if (kIsWeb) return;
    final permissions =
        await BusAlarmService.instance.ensurePermissions(prompt: prompt);
    if (!mounted) return;
    setState(() => _permissions = permissions);
  }

  DateTime get _calculatedRingTime {
    if (_manualRingTimeOverride != null) {
      return _manualRingTimeOverride!;
    }
    final depTime = BusAlarmService.instance.parseTripTimeToDateTime(
      widget.tripTime,
      days: widget.serviceDays,
    );
    return depTime.subtract(Duration(minutes: _selectedLeadMinutes));
  }

  Future<void> _pickManualClockTime() async {
    final initial = _calculatedRingTime;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: 'SELECT EXACT ALARM RING TIME',
    );

    if (pickedTime != null) {
      final now = DateTime.now();
      final depTime = BusAlarmService.instance.parseTripTimeToDateTime(
        widget.tripTime,
        days: widget.serviceDays,
      );

      var target = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (target.isAfter(depTime)) {
        // If picked alarm time is after departure, set for departure day before
        target = target.subtract(const Duration(days: 1));
      }

      final diffMinutes = depTime.difference(target).inMinutes;
      setState(() {
        _manualRingTimeOverride = target;
        _selectedLeadMinutes = diffMinutes > 0 ? diffMinutes : 1;
      });
    }
  }

  Future<void> _onSaveAlarm() async {
    setState(() => _isSaving = true);
    try {
      final alarm = await BusAlarmService.instance.scheduleBusAlarm(
        tripId: widget.tripId,
        routeName: widget.routeName,
        departurePlace: widget.departurePlace,
        tripTime: widget.tripTime,
        busName: widget.busName,
        leadMinutes: _selectedLeadMinutes,
        serviceDays: widget.serviceDays,
      );

      if (!mounted) return;
      widget.onAlarmUpdated?.call();
      Navigator.pop(context, alarm);
    } on BusAlarmException catch (e) {
      // Only reached when the platform itself refuses (or on web). Missing
      // permissions no longer land here — they never block the alarm.
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _recheckPermissions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set alarm: $e')),
      );
    }
  }

  Future<void> _onCancelAlarm() async {
    setState(() => _isSaving = true);
    try {
      await BusAlarmService.instance.cancelBusAlarm(widget.tripId);
      if (!mounted) return;
      widget.onAlarmUpdated?.call();
      Navigator.pop(context, false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  String _formatLeadMinutes(int mins) {
    if (mins < 60) return '$mins mins before';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    if (remMins == 0) return '$hrs hr${hrs > 1 ? "s" : ""} before';
    return '$hrs hr $remMins mins before';
  }

  @override
  Widget build(BuildContext context) {
    final ringFormatted = DateFormat('EEE, h:mm a').format(_calculatedRingTime);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alarm_add_rounded,
                    color: context.colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _existingAlarm != null
                            ? 'Manage Bus Alarm'
                            : 'Set Device Bus Alarm',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${widget.busName} · ${widget.tripTime}',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            if (kIsWeb)
              _WebUnsupportedNotice(
                busName: widget.busName,
                tripTime: widget.tripTime,
              )
            else if (_loading)

              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Permission state, stated plainly. Without this the user had no
              // way to tell a working alarm from one the OS will swallow.
              if (_permissions != null && !_permissions!.isFullyGranted) ...[
                _PermissionWarning(
                  status: _permissions!,
                  onFix: _recheckPermissions,
                ),
                const SizedBox(height: 14),
              ],

              // Trip Summary Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 16,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Leaving from: ${widget.departurePlace}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Lead Time Label
              Text(
                'When should the alarm ring?',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Presets Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._presetLeadTimes.map((mins) {
                    final isSelected =
                        _selectedLeadMinutes == mins && _manualRingTimeOverride == null;
                    return ChoiceChip(
                      label: Text(_formatLeadMinutes(mins)),
                      selected: isSelected,
                      selectedColor: context.colors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : context.colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedLeadMinutes = mins;
                            _manualRingTimeOverride = null;
                          });
                        }
                      },
                    );
                  }),
                ],
              ),

              const SizedBox(height: 12),

              // Fine-Tune Custom Minutes Stepper
              Row(
                children: [
                  Text(
                    'Adjust Minutes:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  _buildStepperButton('-5m', () {
                    if (_selectedLeadMinutes > 5) {
                      setState(() {
                        _selectedLeadMinutes -= 5;
                        _manualRingTimeOverride = null;
                      });
                    }
                  }),
                  const SizedBox(width: 4),
                  _buildStepperButton('-1m', () {
                    if (_selectedLeadMinutes > 1) {
                      setState(() {
                        _selectedLeadMinutes -= 1;
                        _manualRingTimeOverride = null;
                      });
                    }
                  }),
                  const SizedBox(width: 4),
                  _buildStepperButton('+1m', () {
                    if (_selectedLeadMinutes < 300) {
                      setState(() {
                        _selectedLeadMinutes += 1;
                        _manualRingTimeOverride = null;
                      });
                    }
                  }),
                  const SizedBox(width: 4),
                  _buildStepperButton('+5m', () {
                    if (_selectedLeadMinutes < 300) {
                      setState(() {
                        _selectedLeadMinutes += 5;
                        _manualRingTimeOverride = null;
                      });
                    }
                  }),
                ],
              ),

              const SizedBox(height: 16),

              // Live Ring Time Preview Box (Interactive for Manual Clock Time)
              InkWell(
                onTap: _pickManualClockTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        color: context.colors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Alarm Ring Time:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.primary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_calendar_rounded,
                                          size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Set Manual Clock Time',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ringFormatted,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: context.colors.primary,
                              ),
                            ),
                            Text(
                              'Tap here to pick exact clock time · Rings even if app is closed',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  if (_existingAlarm != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _onCancelAlarm,
                        icon: const Icon(Icons.alarm_off_rounded,
                            size: 18, color: Colors.redAccent),
                        label: const Text('Cancel Alarm',
                            style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _onSaveAlarm,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded,
                              size: 18, color: Colors.white),
                      label: Text(
                        _existingAlarm != null
                            ? 'Update Alarm'
                            : 'Set Exact Alarm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepperButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.colors.primary,
          ),
        ),
      ),
    );
  }
}

/// Advisory notice about a switch that would make the alarm work better.
///
/// This is *advice*, never a blocker — the alarm is scheduled regardless.
///
/// It also names the right destination. The notification switch is NOT under
/// "Permissions" on Android 12 and below (POST_NOTIFICATIONS only exists from
/// 13), which is why an earlier version sent users hunting for a permission
/// that wasn't there. The button now deep-links straight to the screen that
/// owns the switch.
class _PermissionWarning extends StatelessWidget {
  final AlarmPermissionStatus status;
  final Future<void> Function() onFix;

  const _PermissionWarning({required this.status, required this.onFix});

  Future<void> _openSettings(BuildContext context) async {
    final target = !status.notificationsGranted
        ? AlarmSettingsTarget.notifications
        : AlarmSettingsTarget.exactAlarms;

    final opened = await BusAlarmService.instance.openAlarmSettings(target);
    if (!context.mounted) return;

    if (!opened) {
      // Some OEM ROMs don't expose these screens; spell out the path instead
      // of leaving a dead button.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open Settings › Apps › BU Horizon › Notifications to turn this on.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
    // Re-read on return so the banner clears itself once it's fixed.
    await onFix();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsOff = !status.notificationsGranted;
    final color =
        notificationsOff ? context.colors.danger : context.colors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            notificationsOff
                ? Icons.notifications_off_rounded
                : Icons.running_with_errors_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationsOff
                      ? 'Notifications are off for BU Horizon'
                      : 'Alarm may ring a few minutes late',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notificationsOff
                      ? 'You can still set the alarm, but it may stay silent. '
                          'The switch is under Notifications (not Permissions).'
                      : 'Exact alarms are off, so Android may delay the '
                          'reminder. Turn on "Alarms & reminders" for exact timing.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => _openSettings(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    notificationsOff
                        ? 'Open notification settings'
                        : 'Open alarm settings',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown inside the picker on Flutter Web, where the OS-level scheduled alarm
/// (`flutter_local_notifications.zonedSchedule`) has no implementation. Rather
/// than let the user set an alarm that can never ring, we explain that the
/// reminder needs the mobile app.
class _WebUnsupportedNotice extends StatelessWidget {
  final String busName;
  final String tripTime;

  const _WebUnsupportedNotice({required this.busName, required this.tripTime});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.colors.warning.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.phonelink_ring_rounded,
                color: context.colors.warning,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarms need the mobile app',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A bus alarm rings on your phone even when the app is '
                      'closed, so it can only be set from the BU Horizon '
                      'Android or iOS app. Open the app to set an alarm for '
                      '$busName ($tripTime).',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
          label: const Text(
            'Got it',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

