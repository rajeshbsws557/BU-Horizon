import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

enum NoticeCategory { academic, events, department }

enum AttendanceStatus { present, absent, upcoming }

enum AlertType { bus, notice, exam, event, library, lostFound }

enum BloodGroup {
  aPositive('A+'),
  aNegative('A-'),
  bPositive('B+'),
  bNegative('B-'),
  abPositive('AB+'),
  abNegative('AB-'),
  oPositive('O+'),
  oNegative('O-');

  final String label;
  const BloodGroup(this.label);
}

@freezed
class QuickAction with _$QuickAction {
  const factory QuickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) = _QuickAction;
}

@freezed
class BusRoute with _$BusRoute {
  const factory BusRoute({
    required String name,
    required String window,
    required String frequency,
    required String nextBus,
    @Default(false) bool favorite,
  }) = _BusRoute;

  factory BusRoute.fromJson(Map<String, Object?> json) =>
      _$BusRouteFromJson(json);
}

@freezed
class ClassNotice with _$ClassNotice {
  const factory ClassNotice({
    required String title,
    required String subtitle,
    required String time,
    required NoticeCategory category,
    required IconData icon,
    required Color color,
  }) = _ClassNotice;
}

@freezed
class Person with _$Person {
  const factory Person({
    required String name,
    required String department,
    required String email,
  }) = _Person;

  const Person._();

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

@freezed
class BloodNeed with _$BloodNeed {
  const factory BloodNeed({
    required int units,
    required BloodGroup group,
    required String contact,
    required String location,
    required String time,
  }) = _BloodNeed;
}

@freezed
class BloodRequest with _$BloodRequest {
  const factory BloodRequest({
    required BloodGroup group,
    required String location,
    required String time,
  }) = _BloodRequest;
}

@freezed
class LostFoundItem with _$LostFoundItem {
  const factory LostFoundItem({
    required String title,
    required String description,
    required String location,
    required String time,
    required bool isLost,
    required IconData icon,
  }) = _LostFoundItem;
}

@freezed
class AttendanceClass with _$AttendanceClass {
  const factory AttendanceClass({
    required String subject,
    required String time,
    required AttendanceStatus status,
  }) = _AttendanceClass;
}

@freezed
class AlertItem with _$AlertItem {
  const factory AlertItem({
    required String title,
    required String subtitle,
    required String time,
    required AlertType type,
  }) = _AlertItem;
}

@freezed
class StudentProfile with _$StudentProfile {
  const factory StudentProfile({
    required String name,
    required String id,
    required String department,
    required String email,
  }) = _StudentProfile;
}
