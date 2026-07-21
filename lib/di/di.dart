import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../repositories/repositories.dart';
import '../supabase/auth_service.dart';
import '../supabase/reference_data_service.dart';
import '../supabase/session_controller.dart';
import '../supabase/supabase_config.dart';
import '../supabase/supabase_course_repository.dart';
import '../supabase/supabase_repositories.dart';
import 'di.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: false,
)
void configureDependencies() {
  init(getIt);
  _registerSupabaseServices();
}

/// Supabase-backed services, registered by hand so the change does not require
/// re-running build_runner on the generated [init] config.
///
/// The generated config binds every content repository to its Sample*
/// implementation (used by UI-only builds and widget tests). When Supabase is
/// configured, the live implementations replace them here.
void _registerSupabaseServices() {
  getIt
    ..registerLazySingleton<AuthService>(AuthService.new)
    ..registerLazySingleton<ReferenceDataService>(ReferenceDataService.new)
    ..registerLazySingleton<SessionController>(
      () => SessionController(getIt<AuthService>()),
    )
    // Not in the generated config: registered by hand like the services above.
    ..registerFactory<BusScheduleRepository>(StaticBusScheduleRepository.new);

  if (SupabaseConfig.isConfigured) {
    getIt.allowReassignment = true;
    getIt
      ..registerFactory<CourseRepository>(SupabaseCourseRepository.new)
      ..registerFactory<NoticeRepository>(SupabaseNoticeRepository.new)
      ..registerFactory<AlertRepository>(SupabaseAlertRepository.new)
      ..registerFactory<AttendanceRepository>(SupabaseAttendanceRepository.new)
      ..registerFactory<BloodRepository>(SupabaseBloodRepository.new)
      ..registerFactory<BusScheduleRepository>(SupabaseBusScheduleRepository.new)
      ..registerFactory<LostFoundRepository>(SupabaseLostFoundRepository.new)
      ..registerFactory<PeopleRepository>(SupabasePeopleRepository.new)
      ..registerFactory<ExamRepository>(SupabaseExamRepository.new)
      ..registerFactory<ResourceRepository>(SupabaseResourceRepository.new);
    getIt.allowReassignment = false;
  }
}
