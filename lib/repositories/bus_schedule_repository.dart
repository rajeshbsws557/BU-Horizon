import '../data/university_bus_schedule_data.dart';

/// Repository for the university bus timetable shown on the bus schedule
/// screen, grouped by category (Student / Teacher / Staff).
///
/// Registered by hand in di.dart (not via injectable codegen), with the live
/// Supabase implementation replacing the static one when Supabase is
/// configured — same pattern as the other Supabase-backed services.
abstract interface class BusScheduleRepository {
  Future<List<UniversityBusCategory>> fetchCategories();
}

/// Bundled timetable used by UI-only builds and widget tests, and kept as the
/// instant-render offline fallback until the live fetch succeeds.
final class StaticBusScheduleRepository implements BusScheduleRepository {
  @override
  Future<List<UniversityBusCategory>> fetchCategories() async =>
      UniversityBusScheduleData.categories;
}
