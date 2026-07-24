// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/bus_alarm_service.dart';
import '../theme/app_theme.dart';

class BusAlarmPickerModal extends StatefulWidget {
  final String tripId;
  final String routeName;
  final String departurePlace;
  final String tripTime;
  final String busName;
  final VoidCallback? onAlarmUpdated;

  const BusAlarmPickerModal({
    super.key,
    required this.tripId,
    required this.routeName,
    required this.departurePlace,
    required this.tripTime,
    required this.busName,
    this.onAlarmUpdated,
  });

  @override
  State<BusAlarmPickerModal> createState() => _BusAlarmPickerModalState();
}

class _BusAlarmPickerModalState extends State<BusAlarmPickerModal> {
  int _selectedLeadMinutes = 15; // Default lead time: 15 minutes before
  DateTime? _manualRingTimeOverride;
  ScheduledBusAlarmInfo? _existingAlarm;
  bool _loading = true;
  bool _isSaving = false;

  final List<int> _presetLeadTimes = [5, 10, 15, 30, 45, 60, 120];

  @override
  void initState() {
    super.initState();
    _checkExistingAlarm();
  }

  Future<void> _checkExistingAlarm() async {
    final alarm = await BusAlarmService.instance.getAlarmForTrip(widget.tripId);
    if (!mounted) return;
    setState(() {
      _existingAlarm = alarm;
      if (alarm != null) {
        _selectedLeadMinutes = alarm.leadMinutes;
        _manualRingTimeOverride = alarm.scheduledRingTime;
      }
      _loading = false;
    });
  }

  DateTime get _calculatedRingTime {
    if (_manualRingTimeOverride != null) {
      return _manualRingTimeOverride!;
    }
    final depTime =
        BusAlarmService.instance.parseTripTimeToDateTime(widget.tripTime);
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
      final depTime =
          BusAlarmService.instance.parseTripTimeToDateTime(widget.tripTime);

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
      );

      if (!mounted) return;
      widget.onAlarmUpdated?.call();
      Navigator.pop(context, alarm);
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

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
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
