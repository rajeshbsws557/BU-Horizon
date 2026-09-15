import 'package:flutter/foundation.dart';

import '../data/university_bus_schedule_data.dart';
import '../repositories/bus_schedule_repository.dart';

class BusScheduleController extends ChangeNotifier {
  final BusScheduleRepository _repository;
  // Large enough to include the university's current Student/Teacher/Staff
  // catalog in one view, while still bounding future backend growth.
  static const int _pageSize = 20;

  BusScheduleController(this._repository);

  List<UniversityBusCategory> categories = UniversityBusScheduleData.categories;
  Set<String> favoriteRouteIds = <String>{};
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  BusScheduleSource source = BusScheduleSource.bundled;
  String? error;
  DateTime? lastSyncedAt;
  int _loadedRoutes = 0;
  bool _initialized = false;
  Future<bool>? _activeRefresh;

  bool get isOffline => source == BusScheduleSource.cachedOffline;

  Future<void> ensureLoaded() async {
    if (_initialized || isLoading) return;
    await refresh();
  }

  Future<bool> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final operation = _performRefresh();
    _activeRefresh = operation;
    operation.whenComplete(() {
      if (identical(_activeRefresh, operation)) _activeRefresh = null;
    });
    return operation;
  }

  Future<bool> _performRefresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.fetchPage(limit: _pageSize),
        _repository.fetchFavoriteRouteIds(),
      ]);
      final page = results[0] as BusSchedulePage;
      if (page.categories.isNotEmpty) categories = page.categories;
      favoriteRouteIds = results[1] as Set<String>;
      _loadedRoutes = _routeCount(categories);
      hasMore = page.hasMore;
      source = page.source;
      if (page.source == BusScheduleSource.live) {
        lastSyncedAt = DateTime.now();
      }
      _initialized = true;
      return true;
    } catch (_) {
      error = 'Live timetable unavailable. Showing the saved campus schedule.';
      if (source == BusScheduleSource.live ||
          source == BusScheduleSource.cachedOffline) {
        source = BusScheduleSource.cachedOffline;
      } else {
        source = BusScheduleSource.bundled;
      }
      _initialized = true;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _repository.fetchPage(
        offset: _loadedRoutes,
        limit: _pageSize,
      );
      categories = _merge(categories, page.categories);
      _loadedRoutes = _routeCount(categories);
      hasMore = page.hasMore;
      source = page.source;
      if (page.source == BusScheduleSource.live) {
        lastSyncedAt = DateTime.now();
      }
      error = null;
    } catch (_) {
      error = 'Could not load more routes. Check your connection and retry.';
      if (source == BusScheduleSource.live) {
        source = BusScheduleSource.cachedOffline;
      }
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String routeId) async {
    final favorite = !favoriteRouteIds.contains(routeId);
    final previous = Set<String>.of(favoriteRouteIds);
    favorite ? favoriteRouteIds.add(routeId) : favoriteRouteIds.remove(routeId);
    notifyListeners();
    try {
      await _repository.setFavorite(routeId, favorite);
    } catch (_) {
      favoriteRouteIds = previous;
      notifyListeners();
      rethrow;
    }
  }

  static int _routeCount(List<UniversityBusCategory> values) =>
      values.fold(0, (count, category) => count + category.routes.length);

  static List<UniversityBusCategory> _merge(
    List<UniversityBusCategory> current,
    List<UniversityBusCategory> incoming,
  ) {
    final grouped = <String, List<UniversityBusRoute>>{
      for (final category in current)
        category.title: List<UniversityBusRoute>.of(category.routes),
    };
    for (final category in incoming) {
      final routes = grouped.putIfAbsent(category.title, () => []);
      for (final route in category.routes) {
        if (!routes.any((existing) => existing.id == route.id)) {
          routes.add(route);
        }
      }
    }
    return [
      for (final entry in grouped.entries)
        UniversityBusCategory(title: entry.key, routes: entry.value),
    ];
  }
}
