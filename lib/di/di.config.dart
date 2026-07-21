// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;

import '../repositories/alert_repository.dart' as _i3;
import '../repositories/attendance_repository.dart' as _i4;
import '../repositories/blood_repository.dart' as _i5;
import '../repositories/bus_repository.dart' as _i6;
import '../repositories/course_repository.dart' as _i7;
import '../repositories/exam_repository.dart' as _i8;
import '../repositories/lost_found_repository.dart' as _i9;
import '../repositories/notice_repository.dart' as _i10;
import '../repositories/people_repository.dart' as _i11;
import '../repositories/resource_repository.dart' as _i12;

// initializes the registration of main-scope dependencies inside of GetIt
_i1.GetIt init(
  _i1.GetIt getIt, {
  String? environment,
  _i2.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i2.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );
  gh.factory<_i3.AlertRepository>(() => _i3.SampleAlertRepository());
  gh.factory<_i4.AttendanceRepository>(() => _i4.SampleAttendanceRepository());
  gh.factory<_i5.BloodRepository>(() => _i5.SampleBloodRepository());
  gh.factory<_i6.BusRepository>(() => _i6.SampleBusRepository());
  gh.lazySingleton<_i7.CourseRepository>(() => _i7.SampleCourseRepository());
  gh.factory<_i8.ExamRepository>(() => _i8.SampleExamRepository());
  gh.factory<_i9.LostFoundRepository>(() => _i9.SampleLostFoundRepository());
  gh.factory<_i10.NoticeRepository>(() => _i10.SampleNoticeRepository());
  gh.factory<_i11.PeopleRepository>(() => _i11.SamplePeopleRepository());
  gh.factory<_i12.ResourceRepository>(() => _i12.SampleResourceRepository());
  return getIt;
}
