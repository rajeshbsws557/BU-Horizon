import '../data/university_bus_schedule_data.dart';

/// Repository for the university bus timetable shown on the bus schedule
/// screen, grouped by category (Student / Teacher / Staff).
///
/// Registered by hand in di.dart (not via injectable codegen), with the live
/// Supabase implementation replacing the static one when Supabase is
/// configured — same pattern as the other Supabase-backed services.
abstract interface class BusScheduleRepository {
  Future<BusSchedulePage> fetchPage({int offset = 0, int limit = 20});

  Future<Set<String>> fetchFavoriteRouteIds();

  Future<void> setFavorite(String routeId, bool favorite);
}

/// Bundled timetable used by UI-only builds and widget tests, and kept as the
/// instant-render offline fallback until the live fetch succeeds.
final class StaticBusScheduleRepository implements BusScheduleRepository {
  final Set<String> _favorites = <String>{};

  @override
  Future<BusSchedulePage> fetchPage({int offset = 0, int limit = 20}) async {
    final routes = [
      for (final category in UniversityBusScheduleData.categories)
        for (final route in category.routes) (category.title, route),
    ];
    final page = routes.skip(offset).take(limit).toList();
    final grouped = <String, List<UniversityBusRoute>>{};
    for (final item in page) {
      grouped.putIfAbsent(item.$1, () => []).add(item.$2);
    }
    return BusSchedulePage(
      categories: [
        for (final category in UniversityBusScheduleData.categories)
          if (grouped.containsKey(category.title))
            UniversityBusCategory(
              title: category.title,
              routes: grouped[category.title]!,
            ),
      ],
      hasMore: offset + page.length < routes.length,
      source: BusScheduleSource.bundled,
    );
  }

  @override
  Future<Set<String>> fetchFavoriteRouteIds() async =>
      Set.unmodifiable(_favorites);

  @override
  Future<void> setFavorite(String routeId, bool favorite) async {
    favorite ? _favorites.add(routeId) : _favorites.remove(routeId);
  }
}
