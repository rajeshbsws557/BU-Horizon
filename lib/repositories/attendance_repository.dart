import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for today's attendance.
abstract interface class AttendanceRepository {
  List<AttendanceClass> get todayClasses;
  ({int present, int total, double percentage}) summary();
}

@Injectable(as: AttendanceRepository)
final class SampleAttendanceRepository implements AttendanceRepository {
  @override
  List<AttendanceClass> get todayClasses =>
      List.unmodifiable(SampleData.todayAttendance);

  @override
  ({int present, int total, double percentage}) summary() {
    final total = SampleData.todayAttendance.length;
    final present = SampleData.todayAttendance
        .where((c) => c.status == AttendanceStatus.present)
        .length;
    final pct = total == 0 ? 0.0 : present / total;
    return (present: present, total: total, percentage: pct);
  }
}
