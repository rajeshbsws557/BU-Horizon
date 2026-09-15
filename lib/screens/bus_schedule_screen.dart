// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/university_bus_schedule_data.dart';
import '../di/di.dart';
import '../services/bus_alarm_service.dart';
import '../services/bus_schedule_controller.dart';
import '../services/next_departure_resolver.dart';
import '../theme/app_theme.dart';
import '../widgets/bus_alarm_picker_modal.dart';
import '../widgets/bus_route_interactive_map.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Canonical campus place name in the bundled + live timetable.
const String _kCampusPlace = 'বিশ্ববিদ্যালয়';

/// Bangla letters that have both a precomposed form and a base+nukta form.
///
/// The two spellings look identical but are different code points, so a plain
/// `==` between a hand-typed constant and a timetable row can silently fail —
/// exactly what used to make the campus checks below never fire. Everything is
/// decomposed before comparison so both spellings meet in the middle.
const Map<int, String> _kBanglaNuktaForms = {
  0x09DC: '\u09A1\u09BC', // ড়
  0x09DD: '\u09A2\u09BC', // ঢ়
  0x09DF: '\u09AF\u09BC', // য়
};

/// Comparison form of a place name: nukta-normalised, trimmed, single-spaced.
String _normalizePlace(String place) {
  final buffer = StringBuffer();
  for (final rune in place.runes) {
    buffer.write(_kBanglaNuktaForms[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Robust campus check: tolerates surrounding whitespace, spelling variants and
/// partial matches that can appear in live Supabase rows.
bool _isCampusPlace(String place) {
  final p = _normalizePlace(place);
  final campus = _normalizePlace(_kCampusPlace);
  return p == campus || p.contains(campus);
}

/// Loose place equality. Live Supabase rows and the printed stop list spell the
/// same stop slightly differently ("রূপাতলী" vs "রূপাতলী হাউজিং"), so a plain
/// `==` would silently drop valid matches.
bool _placesMatch(String a, String b) {
  final x = _normalizePlace(a);
  final y = _normalizePlace(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x == y || x.contains(y) || y.contains(x);
}

/// The printed stop list of a route ("A - B - C") as ordered stop names.
///
/// This is the only place that knows the direction a bus travels in, which is
/// what lets the schedule answer "where can this trip take me?" instead of only
/// "where does it start?".
List<String> _routeStops(UniversityBusRoute route) {
  final desc = route.routeDescription?.trim() ?? '';
  if (desc.isEmpty) return const [];
  return desc
      .split(RegExp(r'\s*[-–—]\s*'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Every place a trip leaving [section] can drop you at, in travel order.
///
/// A [DepartureSection] only stores where a bus *starts*. The destinations are
/// derived from the route itself:
///  * the printed stop list, walked forward (or backward) from the departure
///    point, so intermediate stops count as valid destinations too; and
///  * the opposite section's departure point — the return-leg terminal, and the
///    only signal available for Teacher/Staff routes that carry no stop list.
///
/// The departure point itself is never returned: a bus leaving the university
/// is not a bus that takes you to the university. That inversion was the bug
/// behind "Where to go? → University" listing campus-outbound trips.
@visibleForTesting
List<String> destinationsForSection(
  UniversityBusRoute route,
  DepartureSection section,
) {
  final origin = section.departurePlace.trim();
  final destinations = <String>[];

  void add(String raw) {
    final place = raw.trim();
    if (place.isEmpty) return;
    if (_placesMatch(place, origin)) return; // origin is never a destination
    if (destinations.any((existing) => _placesMatch(existing, place))) return;
    destinations.add(place);
  }

  final stops = _routeStops(route);
  if (stops.isNotEmpty) {
    final originIndex = stops.indexWhere((s) => _placesMatch(s, origin));
    if (originIndex == 0) {
      // Starts at the head of the printed list → travels forward.
      for (final stop in stops.skip(1)) {
        add(stop);
      }
    } else if (originIndex == stops.length - 1) {
      // Starts at the tail (typically the campus) → travels backward.
      for (final stop in stops.reversed.skip(1)) {
        add(stop);
      }
    }
    // A mid-list origin gives no reliable direction, so it falls through to the
    // opposite-terminal signal below rather than guessing.
  }

  for (final other in route.departureSections) {
    add(other.departurePlace);
  }

  return destinations;
}

/// The far terminal of a trip leaving [section] — what the UI shows as the
/// headline "Going to" when no specific place has been picked.
@visibleForTesting
String primaryDestinationFor(
  UniversityBusRoute route,
  DepartureSection section,
) {
  for (final other in route.departureSections) {
    if (!_placesMatch(other.departurePlace, section.departurePlace)) {
      return other.departurePlace.trim();
    }
  }
  final destinations = destinationsForSection(route, section);
  return destinations.isEmpty ? '' : destinations.last;
}

/// Stable, unique id for a single trip. One formula shared by every "Set
/// Alarm" entry point so the same physical trip never yields two ids.
///
/// Exposed via [busScheduleTripId] for tests that guard the "spotlight and
/// list-row Set Alarm agree on the same id" invariant.
String _tripId(
  String routeId,
  String place,
  String time, [
  ServiceDays days = ServiceDays.daily,
]) => busScheduleTripId(routeId, place, time, days);

/// Public seam over the trip-id formula for regression tests. Do not call from
/// UI code — use [_tripId] so the shared formula stays the single source.
///
/// A route with two timetables runs the same clock time on different days
/// (Route 07 leaves at 6:00 PM on both কর্মদিবস and the ছুটি), so [days] is part
/// of the identity. It is appended only for day-scoped blocks, which keeps every
/// pre-existing id byte-identical — alarms users already set survive the update.
@visibleForTesting
String busScheduleTripId(
  String routeId,
  String place,
  String time, [
  ServiceDays days = ServiceDays.daily,
]) => days == ServiceDays.daily
    ? '${routeId}__${place.trim()}__${time.trim()}'
    : '${routeId}__${place.trim()}__${time.trim()}__${days.storageKey}';

enum _TimeBucket { morning, afternoon, evening }

/// Single source of truth for time-of-day bucketing. Parses a real clock time
/// ("8:30 AM", "12:10 PM") instead of matching string prefixes, so 10/11 AM no
/// longer leak into the evening bucket and noon is consistently afternoon.
/// Falls back to [_TimeBucket.morning] when a time can't be parsed.
_TimeBucket _bucketForTime(String rawTime) {
  final minutes = _minutesOfDay(rawTime);
  if (minutes == null) return _TimeBucket.morning;
  if (minutes < 12 * 60) return _TimeBucket.morning; // before 12:00 PM
  if (minutes < 17 * 60) return _TimeBucket.afternoon; // 12:00 PM – 4:59 PM
  return _TimeBucket.evening; // 5:00 PM +
}

/// Minutes since midnight for a "h:mm AM/PM" string, or null if unparseable.
int? _minutesOfDay(String rawTime) {
  final match = RegExp(
    r'(\d{1,2}):(\d{2})\s*([AP]M)',
    caseSensitive: false,
  ).firstMatch(rawTime.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final isPm = match.group(3)!.toUpperCase() == 'PM';
  if (hour == 12) hour = 0; // 12 AM -> 0, 12 PM -> 0 (+12 below)
  if (isPm) hour += 12;
  return hour * 60 + minute;
}

class BusScheduleScreen extends StatelessWidget {
  const BusScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BusScheduleView();
  }
}

class _BusScheduleView extends StatefulWidget {
  const _BusScheduleView();

  @override
  State<_BusScheduleView> createState() => _BusScheduleViewState();
}

class _BusScheduleViewState extends State<_BusScheduleView> {
  late final BusScheduleController _schedule = getIt<BusScheduleController>();
  // Bundled timetable renders instantly; the live rows from Supabase replace
  // it as soon as the fetch completes (and on pull-to-refresh).
  List<UniversityBusCategory> _categories =
      UniversityBusScheduleData.categories;
  bool _syncing = false;
  BusScheduleSource _source = BusScheduleSource.bundled;
  bool _hasMore = false;
  String? _loadError;
  Set<String> _favoriteRouteIds = <String>{};
  bool _showFavoritesOnly = false;
  bool _showFilterHeader = true;

  int _selectedCategoryIndex = 0; // 0: Student, 1: Teacher, 2: Staff
  int _selectedRouteIndex = 0;
  int _selectedDirectionIndex =
      0; // 0: All, 1: Campus Outbound, 2: City Inbound
  bool _showRouteTimeline = false;

  /// User's explicit day-pattern pick for a route that publishes more than one
  /// timetable. Null means "follow today", which is the useful default.
  ServiceDays? _selectedServiceDays;

  String _selectedPlaceFilter = 'All Places';
  String _selectedTimeFilter = 'All Times';

  static const List<String> _availableTimeRanges = [
    'All Times',
    'Morning (Before 12 PM)',
    'Afternoon (12 PM - 5 PM)',
    'Evening (5 PM+)',
  ];

  @override
  void initState() {
    super.initState();
    _schedule.addListener(_scheduleChanged);
    _load();
    // Populate the armed-trip registry so every row and the spotlight card
    // know which trips already have alarms set.
    busAlarmRegistry.refresh();
  }

  @override
  void dispose() {
    _schedule.removeListener(_scheduleChanged);
    super.dispose();
  }

  void _scheduleChanged() {
    if (!mounted) return;
    setState(() {
      _categories = _schedule.categories;
      _syncing = _schedule.isLoading || _schedule.isLoadingMore;
      _source = _schedule.source;
      _hasMore = _schedule.hasMore;
      _loadError = _schedule.error;
      _favoriteRouteIds = Set<String>.of(_schedule.favoriteRouteIds);
      _selectedCategoryIndex = _selectedCategoryIndex.clamp(
        0,
        _categories.length - 1,
      );
      _selectedRouteIndex = _selectedRouteIndex.clamp(
        0,
        _currentCategory.routes.length - 1,
      );
      if (_showFavoritesOnly) {
        final favorite = _selectableRoutes.firstOrNull;
        if (favorite == null) {
          _showFavoritesOnly = false;
        } else if (!_favoriteRouteIds.contains(_currentRoute.id)) {
          _selectedRouteIndex = favorite.$1;
        }
      }
    });
  }

  Future<void> _load() async {
    await _schedule.refresh();
  }

  Future<void> _toggleFavorite(UniversityBusRoute route) async {
    try {
      await _schedule.toggleFavorite(route.id);
    } catch (_) {
      if (mounted) showToast(context, 'Could not update this favorite');
    }
  }

  /// 'All Places' + every place the loaded timetable can actually take you to.
  ///
  /// Built from destinations (not departure points) because this list backs the
  /// "Where to go?" picker — offering a place no bus travels *to* would be a
  /// dead end. The campus is hoisted to the top since it is by far the most
  /// common answer to "where do you want to go?".
  List<String> get _availablePlaces {
    final places = <String>[];
    for (final cat in _categories) {
      for (final r in cat.routes) {
        for (final sec in r.departureSections) {
          for (final destination in destinationsForSection(r, sec)) {
            if (!places.any(
              (existing) => _placesMatch(existing, destination),
            )) {
              places.add(destination);
            }
          }
        }
      }
    }
    places.sort((a, b) {
      final aCampus = _isCampusPlace(a);
      final bCampus = _isCampusPlace(b);
      if (aCampus == bCampus) return 0;
      return aCampus ? -1 : 1;
    });
    return ['All Places', ...places];
  }

  UniversityBusCategory get _currentCategory =>
      _categories[_selectedCategoryIndex];

  UniversityBusRoute get _currentRoute {
    if (_selectedRouteIndex >= _currentCategory.routes.length) {
      return _currentCategory.routes.first;
    }
    return _currentCategory.routes[_selectedRouteIndex];
  }

  bool get _isFilterActive =>
      _selectedPlaceFilter != 'All Places' ||
      _selectedTimeFilter != 'All Times';

  bool get _hasFavoriteRoutes => _currentCategory.routes.any(
    (route) => _favoriteRouteIds.contains(route.id),
  );

  List<(int, UniversityBusRoute)> get _selectableRoutes => [
    for (var i = 0; i < _currentCategory.routes.length; i++)
      if (!_showFavoritesOnly ||
          _favoriteRouteIds.contains(_currentCategory.routes[i].id))
        (i, _currentCategory.routes[i]),
  ];

  /// Distinct day patterns [route] publishes, in printed order. One entry for
  /// every ordinary route; two for Route 07, which has a কর্মদিবস timetable and
  /// a সাপ্তাহিক ছুটি timetable.
  static List<ServiceDays> _servicePatternsFor(UniversityBusRoute route) {
    final patterns = <ServiceDays>[];
    for (final section in route.departureSections) {
      if (!patterns.contains(section.serviceDays)) {
        patterns.add(section.serviceDays);
      }
    }
    return patterns;
  }

  /// Which timetable to show: the user's pick while it is still offered,
  /// otherwise the one that runs today — so opening Route 07 on a Friday lands
  /// on the Friday timetable without any tapping.
  ServiceDays _activeServiceDays(UniversityBusRoute route, {DateTime? now}) {
    final patterns = _servicePatternsFor(route);
    if (patterns.isEmpty) return ServiceDays.daily;
    if (patterns.length == 1) return patterns.first;
    final picked = _selectedServiceDays;
    if (picked != null && patterns.contains(picked)) return picked;
    final today = now ?? DateTime.now();
    return patterns.firstWhere(
      (pattern) => pattern.runsOn(today),
      orElse: () => patterns.first,
    );
  }

  void _onSelectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _selectedRouteIndex = 0;
      _selectedDirectionIndex = 0;
      _selectedServiceDays = null;
      if (_showFavoritesOnly) {
        final first = _selectableRoutes.firstOrNull;
        if (first == null) {
          _showFavoritesOnly = false;
        } else {
          _selectedRouteIndex = first.$1;
        }
      }
    });
  }

  void _onSelectRoute(int index) {
    setState(() {
      _selectedRouteIndex = index;
      // A new route may publish a different set of timetables, so fall back to
      // "whatever runs today" rather than carrying over the previous pick.
      _selectedServiceDays = null;
    });
  }

  void _toggleFavoritesFilter() {
    if (!_hasFavoriteRoutes) return;
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      if (_showFavoritesOnly) {
        final first = _selectableRoutes.firstOrNull;
        if (first != null) _selectedRouteIndex = first.$1;
      }
    });
  }

  /// A trip matches when it *travels to* the picked place — not when it leaves
  /// from it. [destinations] comes from [destinationsForSection], so a bus
  /// leaving the campus is excluded from "Where to go? → University".
  bool _matchesFilter(String tripTime, List<String> destinations) {
    bool matchesPlace = true;
    if (_selectedPlaceFilter != 'All Places') {
      matchesPlace = destinations.any(
        (d) => _placesMatch(d, _selectedPlaceFilter),
      );
    }

    bool matchesTime = true;
    if (_selectedTimeFilter != 'All Times') {
      final bucket = _bucketForTime(tripTime);
      if (_selectedTimeFilter.startsWith('Morning')) {
        matchesTime = bucket == _TimeBucket.morning;
      } else if (_selectedTimeFilter.startsWith('Afternoon')) {
        matchesTime = bucket == _TimeBucket.afternoon;
      } else if (_selectedTimeFilter.startsWith('Evening')) {
        matchesTime = bucket == _TimeBucket.evening;
      }
    }

    return matchesPlace && matchesTime;
  }

  @override
  Widget build(BuildContext context) {
    final route = _currentRoute;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search schedules',
            onPressed: () => _showSearchModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh live schedule',
            onPressed: _syncing ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Toggle Route Map',
            onPressed: () {
              setState(() => _showRouteTimeline = !_showRouteTimeline);
            },
          ),
        ],
        bottom: _syncing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: context.colors.primary.withValues(
                    alpha: 0.12,
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // 1. Permanently Anchored Category Switcher (Student / Teacher / Staff)
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_categories.length, (index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategoryIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _CategoryButton(
                      label: cat.title,
                      isSelected: isSelected,
                      onTap: () => _onSelectCategory(index),
                    ),
                  );
                }),
              ),
            ),
          ),

          // 2. Permanently Anchored Route Selector (Route 01 / Route 02 / Route 03...)
          LayoutBuilder(
            builder: (context, constraints) {
              final routes = _selectableRoutes;
              final compact = constraints.maxWidth < 600;
              return Column(
                children: [
                  if (compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: Builder(
                        builder: (context) {
                          // At large text scales the picker, the star and the
                          // "Favorites" chip cannot share one line, so the
                          // controls drop below the picker instead of clipping.
                          final tight =
                              MediaQuery.textScalerOf(context).scale(12.5) > 17;
                          final picker = _CompactRoutePicker(
                            route: route,
                            onTap: () => _showRoutePicker(context),
                          );
                          final star = IconButton(
                            tooltip: _favoriteRouteIds.contains(route.id)
                                ? 'Remove favorite route'
                                : 'Favorite route',
                            onPressed: () => _toggleFavorite(route),
                            icon: Icon(
                              _favoriteRouteIds.contains(route.id)
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: _favoriteRouteIds.contains(route.id)
                                  ? context.colors.warning
                                  : context.colors.textMuted,
                            ),
                          );
                          final favorites = _FavoritesFilterButton(
                            active: _showFavoritesOnly,
                            enabled: _hasFavoriteRoutes,
                            onTap: _hasFavoriteRoutes
                                ? _toggleFavoritesFilter
                                : null,
                          );
                          if (tight) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                picker,
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    star,
                                    const SizedBox(width: 4),
                                    Flexible(child: favorites),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: picker),
                              const SizedBox(width: 8),
                              star,
                              favorites,
                            ],
                          );
                        },
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: Row(
                        children: [
                          _FavoritesFilterButton(
                            active: _showFavoritesOnly,
                            enabled: _hasFavoriteRoutes,
                            onTap: _hasFavoriteRoutes
                                ? _toggleFavoritesFilter
                                : null,
                          ),
                          const SizedBox(width: 10),
                          ...routes.map((entry) {
                            final index = entry.$1;
                            final r = entry.$2;
                            final isSelected = _selectedRouteIndex == index;
                            String destHint = '';
                            for (final sec in r.departureSections) {
                              if (!_isCampusPlace(sec.departurePlace)) {
                                destHint = sec.departurePlace;
                                break;
                              }
                            }
                            if (destHint.isEmpty &&
                                r.departureSections.isNotEmpty) {
                              destHint =
                                  r.departureSections.first.departurePlace;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _RouteButton(
                                routeName: r.routeName,
                                destinationHint: destHint,
                                isSelected: isSelected,
                                isFavorite: _favoriteRouteIds.contains(r.id),
                                onFavorite: () => _toggleFavorite(r),
                                onTap: () => _onSelectRoute(index),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  // Pagination state is explicit either way: a labelled loading
                  // row while a page is in flight, a "More routes" action when
                  // one is still available.
                  if (_schedule.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading more routes…'),
                        ],
                      ),
                    )
                  else if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton.icon(
                        onPressed: _schedule.loadMore,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('More routes'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          if (_source != BusScheduleSource.live || _loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DataStateBanner(
                message: _source == BusScheduleSource.bundled
                    ? _loadError == null
                          ? 'Saved timetable'
                          : 'Saved timetable. Live updates are unavailable.'
                    : _schedule.lastSyncedAt == null
                    ? 'Offline: showing the last known timetable.'
                    : 'Offline: showing data synced ${formatFreshnessTime(_schedule.lastSyncedAt!)}.',
                tone: _source == BusScheduleSource.bundled && _loadError == null
                    ? DataStateTone.info
                    : DataStateTone.warning,
                onRetry:
                    _loadError != null ||
                        _source == BusScheduleSource.cachedOffline
                    ? _load
                    : null,
              ),
            ),

          if (_source == BusScheduleSource.live &&
              _schedule.lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: LastUpdatedLabel(
                updatedAt: _schedule.lastSyncedAt,
                emptyLabel: 'Timetable not synced yet',
              ),
            ),

          // 3-4. Smooth Collapsible Extra Filters Bar (Collapses only when scrolling down deep)
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.fastOutSlowIn,
            child: _showFilterHeader
                ? AnimatedOpacity(
                    duration: const Duration(milliseconds: 260),
                    opacity: _showFilterHeader ? 1.0 : 0.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Direction Switcher
                        if (!_isFilterActive &&
                            route.departureSections.length > 1)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                            child: Row(
                              children: [
                                _DirectionToggleChip(
                                  icon: Icons.swap_horiz_rounded,
                                  label: 'All Directions',
                                  isSelected: _selectedDirectionIndex == 0,
                                  onTap: () => setState(
                                    () => _selectedDirectionIndex = 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _DirectionToggleChip(
                                  icon: Icons.north_east_rounded,
                                  label: 'From Campus',
                                  isSelected: _selectedDirectionIndex == 1,
                                  onTap: () => setState(
                                    () => _selectedDirectionIndex = 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _DirectionToggleChip(
                                  icon: Icons.south_west_rounded,
                                  label: 'To Campus',
                                  isSelected: _selectedDirectionIndex == 2,
                                  onTap: () => setState(
                                    () => _selectedDirectionIndex = 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Quick Filter Chips (Place / Time)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.filter_alt_rounded,
                                size: 16,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 6),
                              _FilterChipDropdown(
                                icon: Icons.place_rounded,
                                label: _selectedPlaceFilter == 'All Places'
                                    ? 'Where to go?'
                                    : 'Place: $_selectedPlaceFilter',
                                isActive: _selectedPlaceFilter != 'All Places',
                                onTap: () => _showPlacePicker(context),
                              ),
                              const SizedBox(width: 8),
                              _FilterChipDropdown(
                                icon: Icons.access_time_rounded,
                                label: _selectedTimeFilter == 'All Times'
                                    ? 'Time Filter'
                                    : _selectedTimeFilter,
                                isActive: _selectedTimeFilter != 'All Times',
                                onTap: () => _showTimePicker(context),
                              ),
                              if (_isFilterActive) ...[
                                const SizedBox(width: 8),
                                ActionChip(
                                  label: Text(
                                    'Clear Filter',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                  avatar: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: context.colors.primary,
                                  ),
                                  backgroundColor: context.colors.primary
                                      .withValues(alpha: 0.12),
                                  side: BorderSide.none,
                                  onPressed: () {
                                    setState(() {
                                      _selectedPlaceFilter = 'All Places';
                                      _selectedTimeFilter = 'All Times';
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Interactive Google Map (when enabled or toggled)
                        if (_showRouteTimeline)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: BusRouteInteractiveMap(
                              activeRouteId: route.id,
                              onClose: () =>
                                  setState(() => _showRouteTimeline = false),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const Divider(height: 1),

          // 5. Main Scrollable Content (Live Spotlight Hero + Grouped Schedule)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.axis == Axis.vertical) {
                  // Only collapse extra filters when user scrolls down past 120px
                  if (scrollInfo.metrics.extentBefore > 120) {
                    if (_showFilterHeader) {
                      setState(() => _showFilterHeader = false);
                    }
                  } else if (scrollInfo.metrics.extentBefore < 30) {
                    // Restore when user scrolls back near the top (<30px)
                    if (!_showFilterHeader) {
                      setState(() => _showFilterHeader = true);
                    }
                  }
                }
                return false;
              },
              child: RefreshIndicator(
                color: context.colors.primary,
                backgroundColor: context.colors.surfaceAlt,
                onRefresh: _load,
                child: _isFilterActive
                    ? _buildFilteredResultsView(isDark)
                    : _buildRegularScheduleView(route, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredResultsView(bool isDark) {
    // Scope the filter to the category the user is currently viewing so a
    // Student browsing Route 02 doesn't get Teacher/Staff trips mixed in.
    final cat = _currentCategory;
    final results = <Map<String, String>>[];
    for (final r in cat.routes) {
      for (final sec in r.departureSections) {
        final destinations = destinationsForSection(r, sec);
        // Headline the stop the user actually asked for; otherwise the end of
        // the line.
        final goingTo = _selectedPlaceFilter == 'All Places'
            ? primaryDestinationFor(r, sec)
            : destinations.firstWhere(
                (d) => _placesMatch(d, _selectedPlaceFilter),
                orElse: () => primaryDestinationFor(r, sec),
              );
        for (final trip in sec.trips) {
          if (_matchesFilter(trip.time, destinations)) {
            results.add({
              'category': cat.title,
              'route': r.routeName,
              'place': sec.departurePlace,
              'to': goingTo,
              'time': trip.time,
              'bus': trip.busName,
              'desc': r.routeDescription ?? '',
              // Day-scoped hits must say so: an unlabelled 9:00 AM row here
              // reads as "there is a 9 AM bus", which is false Sun–Thu.
              'days': sec.serviceDays.shortLabel,
            });
          }
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 768;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isWide ? 32 : 16,
                14,
                isWide ? 32 : 16,
                24,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 18,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPlaceFilter == 'All Places'
                              ? 'Showing ${results.length} ${cat.title} buses matching your filter'
                              : 'Showing ${results.length} ${cat.title} buses going to $_selectedPlaceFilter',

                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (results.isEmpty)
                  EmptyState(
                    icon: Icons.bus_alert_rounded,
                    title: 'No Matching Buses Found',
                    message:
                        'No available buses found matching your selected Place & Time filter. Try clearing or adjusting filters.',
                  )
                else
                  // One row per trip. The category banner above already states
                  // the category and the destination, and the route's full stop
                  // list was repeated on every single card — both are dropped
                  // here so a filter result is a scannable line, not a block.
                  for (int i = 0; i < results.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 72),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                results[i]['time']!,
                                style: TextStyle(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        results[i]['route']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 12,
                                      color: context.colors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        results[i]['to']!.isEmpty
                                            ? results[i]['place']!
                                            : results[i]['to']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.colors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  results[i]['days']!.isEmpty
                                      ? 'Board at ${results[i]['place']}'
                                      : 'Board at ${results[i]['place']} · runs ${results[i]['days']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _BusNamePillTags(
                                  busNameString: results[i]['bus']!,
                                  isSmall: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegularScheduleView(UniversityBusRoute route, bool isDark) {
    List<DepartureSection> sectionsToShow = [];
    if (_selectedDirectionIndex == 1) {
      sectionsToShow = route.departureSections
          .where((s) => _isCampusPlace(s.departurePlace))
          .toList();
      if (sectionsToShow.isEmpty) sectionsToShow = route.departureSections;
    } else if (_selectedDirectionIndex == 2) {
      sectionsToShow = route.departureSections
          .where((s) => !_isCampusPlace(s.departurePlace))
          .toList();
      if (sectionsToShow.isEmpty) sectionsToShow = route.departureSections;
    } else {
      sectionsToShow = route.departureSections;
    }

    // A route with two timetables shows one at a time. Mixing them would put a
    // Fri & Sat 9:00 AM row next to a কর্মদিবস 6:00 PM row with nothing to say
    // which of them runs today, and would feed both to the spotlight card.
    final patterns = _servicePatternsFor(route);
    final activeDays = _activeServiceDays(route);
    if (patterns.length > 1) {
      final dayScoped = sectionsToShow
          .where((s) => s.serviceDays == activeDays)
          .toList();
      if (dayScoped.isNotEmpty) sectionsToShow = dayScoped;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (patterns.length > 1) ...[
                  _ServiceDaysToggle(
                    patterns: patterns,
                    active: activeDays,
                    onSelect: (days) =>
                        setState(() => _selectedServiceDays = days),
                  ),
                  const SizedBox(height: 14),
                ],
                Entrance(
                  index: 0,
                  child: _LiveNextBusSpotlightCard(
                    route: route,
                    sections: sectionsToShow,
                  ),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < sectionsToShow.length; i++)
                  Entrance(
                    key: ValueKey('${route.id}_section_$i'),
                    index: i + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DepartureSectionCard(
                        routeId: route.id,
                        routeName: route.routeName,
                        section: sectionsToShow[i],
                      ),
                    ),
                  ),
                // The full stop list is reference material rather than
                // something you re-read on every visit, so it starts collapsed.
                // The map used to be rendered *again* here at full height even
                // though the header toggle already shows it — that duplicate
                // roughly doubled the page height for the same information.
                if (route.routeDescription != null &&
                    route.routeDescription!.isNotEmpty)
                  Entrance(
                    key: ValueKey('${route.id}_desc'),
                    index: sectionsToShow.length + 1,
                    child: _RouteStopsSummary(
                      routeName: route.routeName,
                      stops: route.routeDescription!,
                      onShowMap: _showRouteTimeline
                          ? null
                          : () => setState(() => _showRouteTimeline = true),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'BU Horizon · Developed by Rajesh Biswas (rajeshbiswas.dev)',
                    style: TextStyle(
                      color: context.colors.textMuted.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlacePicker(BuildContext context) {
    // Destinations include every reachable stop, so this list is long: it gets
    // its own bounded, scrollable sheet instead of a Column that would run off
    // the bottom of the screen (and take the first entries with it).
    final places = _availablePlaces;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Where You Want To Go',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: places.length,
                    itemBuilder: (_, index) {
                      final p = places[index];
                      return ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(p),
                        selected: _selectedPlaceFilter == p,
                        selectedColor: context.colors.primary,
                        onTap: () {
                          setState(() => _selectedPlaceFilter = p);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRoutePicker(BuildContext context) {
    final routes = _selectableRoutes;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose a route',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Flexible(
                child: routes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No favorite routes in this category.'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: routes.length,
                        itemBuilder: (_, index) {
                          final (routeIndex, candidate) = routes[index];
                          return ListTile(
                            leading: Icon(
                              _favoriteRouteIds.contains(candidate.id)
                                  ? Icons.star_rounded
                                  : Icons.alt_route_rounded,
                              color: _favoriteRouteIds.contains(candidate.id)
                                  ? context.colors.warning
                                  : context.colors.primary,
                            ),
                            title: Text(candidate.routeName),
                            subtitle: Text(
                              candidate.departureSections.isEmpty
                                  ? 'Timetable unavailable'
                                  : candidate
                                        .departureSections
                                        .first
                                        .departurePlace,
                            ),
                            selected: _selectedRouteIndex == routeIndex,
                            onTap: () {
                              _onSelectRoute(routeIndex);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Filter Available Buses By Time',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                for (final t in _availableTimeRanges)
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: Text(t),
                    selected: _selectedTimeFilter == t,
                    selectedColor: context.colors.primary,
                    onTap: () {
                      setState(() => _selectedTimeFilter = t);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BusScheduleSearchSheet(categories: _categories),
    );
  }
}

/// Overrides "now" for the spotlight card in widget tests, so a test can assert
/// on a specific departure instead of whatever time the suite happens to run
/// at. Null in production, where the real clock is used.
@visibleForTesting
DateTime Function()? debugNextDepartureClock;

/// The "Next Departure" hero card.
///
/// Previously this rendered `sections.first.trips.first` — the first row of the
/// printed timetable — so it showed the 8:30 AM bus at 9 PM and never changed.
/// It is now driven by [resolveNextDeparture] against the live clock and ticks
/// once a second so the countdown, the highlighted trip and the "Set Alarm"
/// target all stay correct without a manual refresh.
class _LiveNextBusSpotlightCard extends StatefulWidget {
  final UniversityBusRoute route;
  final List<DepartureSection> sections;

  const _LiveNextBusSpotlightCard({
    required this.route,
    required this.sections,
  });

  @override
  State<_LiveNextBusSpotlightCard> createState() =>
      _LiveNextBusSpotlightCardState();
}

class _LiveNextBusSpotlightCardState extends State<_LiveNextBusSpotlightCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// One-second cadence so the countdown reads like a clock, and so the card
  /// rolls over to the following bus on its own the moment one departs. The
  /// rebuild is a cheap subtree (no layout thrash) and the timer is cancelled
  /// in [dispose], so it can't outlive the screen.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  DateTime get _now => debugNextDepartureClock?.call() ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final route = widget.route;

    if (sections.isEmpty || sections.every((s) => s.trips.isEmpty)) {
      return const SizedBox.shrink();
    }

    final now = _now;
    final next = resolveNextDeparture(sections, now: now);

    // Every trip label was unparseable (bad live data). Rather than show a
    // wrong "next bus", fall back to the old first-row behaviour.
    if (next == null) {
      final fallbackSection = sections.firstWhere((s) => s.trips.isNotEmpty);
      return _buildCard(
        context,
        departurePlace: fallbackSection.departurePlace,
        trip: fallbackSection.trips.first,
        countdownLabel: null,
        dayLabel: '',
        serviceDays: fallbackSection.serviceDays,
        isBoarding: false,
        routeName: route.routeName,
        routeId: route.id,
      );
    }

    final remaining = next.timeUntil(now);
    return _buildCard(
      context,
      departurePlace: next.departurePlace,
      trip: next.trip,
      countdownLabel: formatCountdown(remaining),
      // Not just "Tomorrow" any more: a Fri & Sat block seen on a Tuesday is
      // several days out and names its weekday instead.
      dayLabel: formatDepartureDay(next.daysAhead, next.departsAt),
      serviceDays: next.serviceDays,
      // Within a minute either side of departure: the bus is at the stop now.
      isBoarding: remaining.inSeconds <= 0,
      routeName: route.routeName,
      routeId: route.id,
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String departurePlace,
    required BusTripItem trip,
    required String? countdownLabel,
    required String dayLabel,
    required ServiceDays serviceDays,
    required bool isBoarding,
    required String routeName,
    required String routeId,
  }) {
    // Flips to green the moment the bus is due, so the card's colour alone
    // tells you whether you still have time to walk over.
    final accent = isBoarding ? context.colors.success : context.colors.primary;

    return GlassCard(
      gradient: context.colors.heroGradient,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // spaceBetween (rather than a Spacer) keeps the status pill left and
          // the countdown right while letting the pill's label ellipsise. With a
          // flexible spacer both pills were intrinsically sized and together
          // overflowed a 360dp phone by ~60px.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 15, color: accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isBoarding ? 'DEPARTING NOW' : 'NEXT DEPARTURE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // The live countdown — the piece that makes this card feel
              // "alive" instead of a frozen timetable row.
              if (countdownLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: inkOn(accent),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBoarding ? 'At the stop' : 'in $countdownLabel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: inkOn(accent),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  Icons.directions_bus_filled_rounded,
                  color: context.colors.primary.withValues(alpha: 0.7),
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final timeBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.time,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  // After the last bus of the day, be explicit about which day
                  // this one leaves rather than implying it's still coming.
                  if (dayLabel.isNotEmpty)
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMuted,
                      ),
                    ),
                ],
              );
              final placeBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From $departurePlace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _BusNamePillTags(
                    busNameString: trip.busName,
                    isSmall: true,
                  ),
                ],
              );
              final alarm = _TripAlarmButton(
                tripId: _tripId(
                  routeId,
                  departurePlace,
                  trip.time,
                  serviceDays,
                ),
                routeName: routeName,
                departurePlace: departurePlace,
                tripTime: trip.time,
                busName: trip.busName,
                serviceDays: serviceDays,
                dense: false,
              );

              // The 22px time, the stop name and the alarm button stop fitting
              // on one line well before the maximum text scale, so above ~1.35x
              // the stop name moves to its own line instead of being clipped.
              final stacked =
                  MediaQuery.textScalerOf(context).scale(22) > 30;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: timeBlock),
                        const SizedBox(width: 8),
                        alarm,
                      ],
                    ),
                    const SizedBox(height: 8),
                    placeBlock,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  timeBlock,
                  const SizedBox(width: 12),
                  Expanded(child: placeBlock),
                  alarm,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DirectionToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirectionToggleChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The selected chip is a primary-tinted fill, so its label needs a deeper
    // ink than `primary` itself: primary-on-primary-tint measured 3.45:1.
    final selectedInk = context.isLight
        ? context.colors.primaryDark
        : context.colors.primary;
    return Pressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primary.withValues(alpha: 0.18)
                  : context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? context.colors.primary
                    : context.colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? selectedInk
                      : context.colors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? selectedInk
                        : context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChipDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChipDropdown({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isActive
                    ? context.colors.primary.withValues(alpha: 0.15)
                    : context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? context.colors.primary
                      : context.colors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: isActive
                        ? context.colors.primary
                        : context.colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: isActive
                          ? context.colors.primary
                          : context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isActive
                        ? context.colors.primary
                        : context.colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.primary
                : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? context.colors.primary
                  : context.colors.border,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? inkOn(context.colors.primary)
                  : context.colors.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  final String routeName;
  final String destinationHint;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const _RouteButton({
    required this.routeName,
    required this.destinationHint,
    required this.isSelected,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // One ink colour for everything drawn on the selected fill, so the label,
    // the destination chip and the star all stay legible in every palette.
    final selectedInk = inkOn(context.colors.primary);
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary
              : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        routeName,
                        style: TextStyle(
                          color: isSelected
                              ? selectedInk
                              : context.colors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (destinationHint.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 130),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedInk.withValues(alpha: 0.22)
                                : context.colors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            destinationHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? selectedInk
                                  : context.colors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: isFavorite ? 'Remove favorite route' : 'Favorite route',
              child: IconButton(
                tooltip: isFavorite
                    ? 'Remove favorite route'
                    : 'Favorite route',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 21,
                  color: isSelected
                      ? selectedInk
                      : isFavorite
                      ? context.colors.warning
                      : context.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRoutePicker extends StatelessWidget {
  final UniversityBusRoute route;
  final VoidCallback onTap;

  const _CompactRoutePicker({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Choose bus route, currently ${route.routeName}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.alt_route_rounded, color: context.colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    route.routeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: context.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritesFilterButton extends StatelessWidget {
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  const _FavoritesFilterButton({
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? context.colors.warning : context.colors.textMuted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: active ? 'Showing favorite routes' : 'Show favorite routes',
      child: Tooltip(
        message: enabled ? 'Favorites' : 'No favorite routes yet',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.16)
                    : context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? color : context.colors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Favorites',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? context.colors.textPrimary : color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bus operator chips ("BRTC, সুগন্ধা").
///
/// Labels come from [busOperatorChipLabels], which expands the timetable's
/// "name the operator once" shorthand so an abbreviated entry reads as a bus
/// rather than a stray number.
///
/// Each chip is capped to the width actually available and ellipsised. Without
/// that cap a single long operator name renders wider than its card and spills
/// out the side — the "leaking bus name" the schedule used to show.
class _BusNamePillTags extends StatelessWidget {
  final String busNameString;
  final bool isSmall;

  const _BusNamePillTags({required this.busNameString, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    final parts = busOperatorChipLabels(busNameString);

    if (parts.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Finite in every current call site (all are inside an Expanded), but
        // guard anyway so the chip can't grow unbounded in a future layout.
        final maxPillWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: parts.map((name) {
            final isBrtc =
                name.toUpperCase().contains('BRTC') ||
                name.contains('বিআরটিসি');
            final tagColor = isBrtc
                ? context.colors.primary
                : context.colors.accentCyan;
            final horizontalPadding = isSmall ? 7.0 : 9.0;
            final iconSize = isSmall ? 11.5 : 13.0;
            // In a very narrow slot the icon alone can exceed the pill's own
            // width budget — the Flexible text can shrink to zero, the icon
            // cannot. Below that threshold the operator name is what matters,
            // so the icon is dropped rather than overflowing the row.
            final contentWidth =
                maxPillWidth - (horizontalPadding * 2) - 2; // 2 = border
            final showIcon =
                !maxPillWidth.isFinite || contentWidth >= iconSize + 4 + 14;

            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxPillWidth),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isSmall ? 2.5 : 4,
                ),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tagColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIcon) ...[
                      Icon(
                        isBrtc
                            ? Icons.directions_bus_rounded
                            : Icons.commute_rounded,
                        size: iconSize,
                        color: tagColor,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: tagColor,
                          fontWeight: FontWeight.w700,
                          fontSize: isSmall ? 11 : 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Trip ids that currently have an armed alarm, shared by every "Set Alarm"
/// entry point on this screen.
///
/// The schedule renders dozens of rows plus the spotlight card; reading
/// SharedPreferences from each one would be wasteful and would leave the others
/// stale after a set or cancel. One notifier keeps them all in agreement.
final BusAlarmRegistry busAlarmRegistry = BusAlarmRegistry();

@visibleForTesting
class BusAlarmRegistry
    extends ValueNotifier<Map<String, ScheduledBusAlarmInfo>> {
  BusAlarmRegistry() : super(const {});

  /// Re-reads stored alarms. Elapsed ones are dropped so a row can't advertise
  /// an alarm that already rang.
  Future<void> refresh() async {
    try {
      final alarms = await BusAlarmService.instance.getScheduledAlarms();
      final now = DateTime.now();
      value = {
        for (final alarm in alarms)
          if (alarm.scheduledRingTime.isAfter(now)) alarm.id: alarm,
      };
    } catch (_) {
      // No storage on this host (unit-test binding): keep what we had rather
      // than blanking every row's state.
    }
  }
}

/// "Set alarm" / "alarm armed" control for one trip.
///
/// Every row used to render the same neutral bell whether or not an alarm was
/// set, so the only way to find an alarm you had already made was to open each
/// trip in turn. Armed trips now read as armed, and tapping opens the same
/// sheet in its edit/cancel form.
class _TripAlarmButton extends StatelessWidget {
  final String tripId;
  final String routeName;
  final String departurePlace;
  final String tripTime;
  final String busName;

  /// Days the owning section runs, so the alarm is armed for a date the bus
  /// actually leaves rather than simply "tomorrow".
  final ServiceDays serviceDays;

  /// Icon-sized for dense timetable rows; labelled for the spotlight hero.
  final bool dense;

  const _TripAlarmButton({
    required this.tripId,
    required this.routeName,
    required this.departurePlace,
    required this.tripTime,
    required this.busName,
    this.serviceDays = ServiceDays.daily,
    this.dense = true,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BusAlarmPickerModal(
        tripId: tripId,
        routeName: routeName,
        departurePlace: departurePlace,
        tripTime: tripTime,
        busName: busName,
        serviceDays: serviceDays,
      ),
    );

    // Re-read before touching the UI so every entry point flips at once.
    await busAlarmRegistry.refresh();
    if (!context.mounted) return;
    if (result is ScheduledBusAlarmInfo) {
      showToast(
        context,
        'Alarm set for ${result.tripTime} (${result.leadMinutes} mins before)',
      );
    } else if (result == false) {
      showToast(context, 'Alarm cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ScheduledBusAlarmInfo>>(
      valueListenable: busAlarmRegistry,
      builder: (context, alarms, _) {
        final alarm = alarms[tripId];
        final isArmed = alarm != null;
        final accent = isArmed
            ? context.colors.success
            : context.colors.primary;
        final tooltip = isArmed
            ? 'Alarm rings ${_formatClock(alarm.scheduledRingTime)} '
                  '(${alarm.leadMinutes} min before) · tap to edit'
            : 'Set alarm for $tripTime';

        return Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openPicker(context),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 8 : 11,
                  vertical: dense ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  // Armed rows get a solid fill so they stand out down a long
                  // list; unarmed stay quiet.
                  color: isArmed
                      ? accent.withValues(alpha: dense ? 0.16 : 1.0)
                      : (dense ? Colors.transparent : accent),
                  borderRadius: BorderRadius.circular(10),
                  border: isArmed && dense
                      ? Border.all(color: accent.withValues(alpha: 0.55))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isArmed
                          ? Icons.alarm_on_rounded
                          : Icons.alarm_add_rounded,
                      size: dense ? 16 : 15,
                      color: dense
                          ? accent
                          : (isArmed ? Colors.white : Colors.white),
                    ),
                    if (isArmed && dense) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${alarm.leadMinutes}m',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                    if (!dense) ...[
                      const SizedBox(width: 5),
                      Text(
                        isArmed ? 'Edit' : 'Alarm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "7:15 AM" for an alarm's ring time.
String _formatClock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

class _DepartureSectionCard extends StatelessWidget {
  final String routeId;
  final String routeName;
  final DepartureSection section;

  const _DepartureSectionCard({
    required this.routeId,
    required this.routeName,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final morningTrips = <BusTripItem>[];
    final afternoonTrips = <BusTripItem>[];
    final eveningTrips = <BusTripItem>[];

    for (final trip in section.trips) {
      switch (_bucketForTime(trip.time)) {
        case _TimeBucket.morning:
          morningTrips.add(trip);
        case _TimeBucket.afternoon:
          afternoonTrips.add(trip);
        case _TimeBucket.evening:
          eveningTrips.add(trip);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.departurePlace,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                // Only day-scoped blocks are labelled; an unqualified timetable
                // would just carry a meaningless "Every day" badge.
                if (section.serviceDays != ServiceDays.daily) ...[
                  const SizedBox(width: 8),
                  _ServiceDaysChip(days: section.serviceDays),
                ],
              ],
            ),
          ),
          if (section.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      section.note!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (morningTrips.isNotEmpty)
            _TripGroupSection(
              title: 'Morning Trips (সকাল)',
              icon: Icons.wb_sunny_rounded,
              iconColor: context.colors.warning,
              routeId: routeId,
              routeName: routeName,
              departurePlace: section.departurePlace,
              serviceDays: section.serviceDays,
              trips: morningTrips,
            ),
          if (afternoonTrips.isNotEmpty)
            _TripGroupSection(
              title: 'Afternoon Trips (দুপুর)',
              icon: Icons.light_mode_rounded,
              iconColor: context.colors.accentCyan,
              routeId: routeId,
              routeName: routeName,
              departurePlace: section.departurePlace,
              serviceDays: section.serviceDays,
              trips: afternoonTrips,
            ),
          if (eveningTrips.isNotEmpty)
            _TripGroupSection(
              title: 'Evening & Night Trips (রাত)',
              icon: Icons.nights_stay_rounded,
              iconColor: context.colors.purple,
              routeId: routeId,
              routeName: routeName,
              departurePlace: section.departurePlace,
              serviceDays: section.serviceDays,
              trips: eveningTrips,
            ),
        ],
      ),
    );
  }
}

/// Timetable switcher for a route that publishes more than one — the campus ⟷
/// রুপাতলী service runs a short evening timetable on কর্মদিবস and a near
/// all-day one on the সাপ্তাহিক ছুটি.
///
/// It opens on whichever timetable applies today, and says so, because "which
/// of these two applies to me right now" is the only question a student
/// actually has here.
class _ServiceDaysToggle extends StatelessWidget {
  final List<ServiceDays> patterns;
  final ServiceDays active;
  final ValueChanged<ServiceDays> onSelect;

  const _ServiceDaysToggle({
    required this.patterns,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_repeat_rounded,
                size: 15,
                color: context.colors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This route runs two timetables',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pattern in patterns)
                _DirectionToggleChip(
                  icon: pattern.runsOn(today)
                      ? Icons.today_rounded
                      : Icons.calendar_month_rounded,
                  label: pattern.runsOn(today)
                      ? '${pattern.shortLabel} · Today'
                      : pattern.shortLabel,
                  isSelected: pattern == active,
                  onTap: () => onSelect(pattern),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Sun–Thu" / "Fri & Sat" badge on a departure-section header. Only rendered
/// for routes that publish more than one timetable, so a plain route stays
/// visually unchanged.
class _ServiceDaysChip extends StatelessWidget {
  final ServiceDays days;

  const _ServiceDaysChip({required this.days});

  @override
  Widget build(BuildContext context) {
    final color = days == ServiceDays.weekend
        ? context.colors.purple
        : context.colors.accentCyan;
    return Semantics(
      label: 'Runs on ${days.longLabel}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          days.shortLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: context.isLight ? color : context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TripGroupSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String routeId;
  final String routeName;
  final String departurePlace;
  final ServiceDays serviceDays;
  final List<BusTripItem> trips;

  const _TripGroupSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.routeId,
    required this.routeName,
    required this.departurePlace,
    required this.trips,
    this.serviceDays = ServiceDays.daily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              // Expanded so a long group title wraps instead of overflowing at
              // large text scales.
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: List.generate(trips.length, (index) {
              final trip = trips[index];
              final isLast = index == trips.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 72),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              trip.time,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BusNamePillTags(
                            busNameString: trip.busName,
                            isSmall: true,
                          ),
                        ),
                        _TripAlarmButton(
                          tripId: _tripId(
                            routeId,
                            departurePlace,
                            trip.time,
                            serviceDays,
                          ),
                          routeName: routeName,
                          departurePlace: departurePlace,
                          tripTime: trip.time,
                          busName: trip.busName,
                          serviceDays: serviceDays,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 0.8,
                      color: context.colors.border.withValues(alpha: 0.5),
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Collapsible stop summary — collapsed by default to save space.
class _RouteStopsSummary extends StatefulWidget {
  final String routeName;
  final String stops;
  final VoidCallback? onShowMap;

  const _RouteStopsSummary({
    required this.routeName,
    required this.stops,
    this.onShowMap,
  });

  @override
  State<_RouteStopsSummary> createState() => _RouteStopsSummaryState();
}

class _RouteStopsSummaryState extends State<_RouteStopsSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.alt_route_rounded,
                    size: 16,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.routeName} Stops',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                  if (widget.onShowMap != null)
                    TextButton.icon(
                      onPressed: widget.onShowMap,
                      icon: const Icon(Icons.map_outlined, size: 14),
                      label: const Text(
                        'Map',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: context.colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                widget.stops,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _BusScheduleSearchSheet extends StatefulWidget {
  final List<UniversityBusCategory> categories;

  const _BusScheduleSearchSheet({required this.categories});

  @override
  State<_BusScheduleSearchSheet> createState() =>
      _BusScheduleSearchSheetState();
}

class _BusScheduleSearchSheetState extends State<_BusScheduleSearchSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final allResults = <Map<String, String>>[];
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      for (final cat in widget.categories) {
        for (final route in cat.routes) {
          for (final sec in route.departureSections) {
            for (final trip in sec.trips) {
              if (trip.time.toLowerCase().contains(q) ||
                  trip.busName.toLowerCase().contains(q) ||
                  sec.departurePlace.toLowerCase().contains(q) ||
                  route.routeName.toLowerCase().contains(q)) {
                allResults.add({
                  'category': cat.title,
                  'route': route.routeName,
                  'place': sec.departurePlace,
                  'time': trip.time,
                  'bus': trip.busName,
                });
              }
            }
          }
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search_rounded, color: context.colors.primary),
                const SizedBox(width: 10),
                const Text(
                  'Search Bus Schedule',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText:
                    'Search by time, bus code, or place (e.g. 8:30 AM, সুগন্ধা)...',
                prefixIcon: const Icon(Icons.directions_bus_rounded),
                filled: true,
                fillColor: context.colors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => query = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: query.trim().isEmpty
                  ? Center(
                      child: Text(
                        'Type above to search across all Student, Teacher & Staff routes.',
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    )
                  : allResults.isEmpty
                  ? Center(
                      child: Text(
                        'No matching bus trips found.',
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: allResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = allResults[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.primary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(13),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 15,
                                      color: context.colors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'DEPARTURE PLACE : ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.primary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item['place']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['time']!,
                                        style: TextStyle(
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item['category']} · ${item['route']}',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          _BusNamePillTags(
                                            busNameString: item['bus']!,
                                            isSmall: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
