// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'package:flutter/material.dart';

import '../data/university_bus_schedule_data.dart';
import '../di/di.dart';
import '../repositories/bus_schedule_repository.dart';
import '../services/bus_alarm_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bus_alarm_picker_modal.dart';
import '../widgets/bus_route_interactive_map.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Canonical campus place name in the bundled + live timetable.
const String _kCampusPlace = 'বিশ্ববিদ্যালয়';

/// Robust campus check: tolerates surrounding whitespace / partial matches
/// that can appear in live Supabase rows (a single stray char used to break
/// the direction filter silently).
bool _isCampusPlace(String place) {
  final p = place.trim();
  return p == _kCampusPlace || p.contains(_kCampusPlace);
}

/// Stable, unique id for a single trip. One formula shared by every "Set
/// Alarm" entry point so the same physical trip never yields two ids.
///
/// Exposed via [busScheduleTripId] for tests that guard the "spotlight and
/// list-row Set Alarm agree on the same id" invariant.
String _tripId(String routeId, String place, String time) =>
    busScheduleTripId(routeId, place, time);

/// Public seam over the trip-id formula for regression tests. Do not call from
/// UI code — use [_tripId] so the shared formula stays the single source.
@visibleForTesting
String busScheduleTripId(String routeId, String place, String time) =>
    '${routeId}__${place.trim()}__${time.trim()}';

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
  final match =
      RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false)
          .firstMatch(rawTime.trim());
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
  // Bundled timetable renders instantly; the live rows from Supabase replace
  // it as soon as the fetch completes (and on pull-to-refresh).
  List<UniversityBusCategory> _categories = UniversityBusScheduleData.categories;
  bool _syncing = false;
  bool _showFilterHeader = true;

  int _selectedCategoryIndex = 0; // 0: Student, 1: Teacher, 2: Staff
  int _selectedRouteIndex = 0;
  int _selectedDirectionIndex = 0; // 0: All, 1: Campus Outbound, 2: City Inbound
  bool _showRouteTimeline = false;

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
    _load();
  }

  Future<void> _load() async {
    setState(() => _syncing = true);
    try {
      final categories = await getIt<BusScheduleRepository>().fetchCategories();
      if (!mounted) return;
      setState(() {
        if (categories.isNotEmpty) {
          _categories = categories;
          _selectedCategoryIndex =
              _selectedCategoryIndex.clamp(0, categories.length - 1);
          _selectedRouteIndex = 0;
        }
        _syncing = false;
      });
    } catch (_) {
      // Keep showing the bundled timetable (same printed schedule) offline.
      if (!mounted) return;
      setState(() => _syncing = false);
    }
  }

  /// 'All Places' + every departure place present in the loaded timetable.
  List<String> get _availablePlaces {
    final places = <String>{};
    for (final cat in _categories) {
      for (final r in cat.routes) {
        for (final sec in r.departureSections) {
          places.add(sec.departurePlace);
        }
      }
    }
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
      _selectedPlaceFilter != 'All Places' || _selectedTimeFilter != 'All Times';

  void _onSelectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _selectedRouteIndex = 0;
      _selectedDirectionIndex = 0;
    });
  }

  void _onSelectRoute(int index) {
    setState(() {
      _selectedRouteIndex = index;
    });
  }

  bool _matchesFilter(String tripTime, String departurePlace) {
    bool matchesPlace = true;
    if (_selectedPlaceFilter != 'All Places') {
      matchesPlace = departurePlace.contains(_selectedPlaceFilter) ||
          _selectedPlaceFilter.contains(departurePlace);
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
                  backgroundColor: context.colors.primary.withValues(alpha: 0.12),
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
                children: List.generate(
                  _categories.length,
                  (index) {
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
                  },
                ),
              ),
            ),
          ),

          // 2. Permanently Anchored Route Selector (Route 01 / Route 02 / Route 03...)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: List.generate(
                _currentCategory.routes.length,
                (index) {
                  final r = _currentCategory.routes[index];
                  final isSelected = _selectedRouteIndex == index;
                  String destHint = '';
                  for (final sec in r.departureSections) {
                    if (!_isCampusPlace(sec.departurePlace)) {
                      destHint = sec.departurePlace;
                      break;
                    }
                  }
                  if (destHint.isEmpty && r.departureSections.isNotEmpty) {
                    destHint = r.departureSections.first.departurePlace;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _RouteButton(
                      routeName: r.routeName,
                      destinationHint: destHint,
                      isSelected: isSelected,
                      onTap: () => _onSelectRoute(index),
                    ),
                  );
                },
              ),
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
                        if (!_isFilterActive && route.departureSections.length > 1)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                            child: Row(
                              children: [
                                _DirectionToggleChip(
                                  icon: Icons.swap_horiz_rounded,
                                  label: 'All Directions',
                                  isSelected: _selectedDirectionIndex == 0,
                                  onTap: () => setState(() => _selectedDirectionIndex = 0),
                                ),
                                const SizedBox(width: 8),
                                _DirectionToggleChip(
                                  icon: Icons.north_east_rounded,
                                  label: 'From Campus',
                                  isSelected: _selectedDirectionIndex == 1,
                                  onTap: () => setState(() => _selectedDirectionIndex = 1),
                                ),
                                const SizedBox(width: 8),
                                _DirectionToggleChip(
                                  icon: Icons.south_west_rounded,
                                  label: 'To Campus',
                                  isSelected: _selectedDirectionIndex == 2,
                                  onTap: () => setState(() => _selectedDirectionIndex = 2),
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
                              Icon(Icons.filter_alt_rounded,
                                  size: 16, color: context.colors.primary),
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
                                  avatar: Icon(Icons.close_rounded,
                                      size: 14, color: context.colors.primary),
                                  backgroundColor: context.colors.primary.withValues(alpha: 0.12),
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
                              onClose: () => setState(() => _showRouteTimeline = false),
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
        for (final trip in sec.trips) {
          if (_matchesFilter(trip.time, sec.departurePlace)) {
            results.add({
              'category': cat.title,
              'route': r.routeName,
              'place': sec.departurePlace,
              'time': trip.time,
              'bus': trip.busName,
              'desc': r.routeDescription ?? '',
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
                  isWide ? 32 : 16, 14, isWide ? 32 : 16, 24),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_rounded,
                          size: 18, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing ${results.length} ${cat.title} buses matching your filter',
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
                  for (int i = 0; i < results.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(alpha: 0.14),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 16, color: context.colors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'DEPARTURE PLACE : ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    results[i]['place']!,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    results[i]['time']!,
                                    style: TextStyle(
                                      color: context.colors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${results[i]['category']} · ${results[i]['route']}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: context.colors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _BusNamePillTags(
                                          busNameString: results[i]['bus']!),
                                      if (results[i]['desc']!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          results[i]['desc']!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.colors.textMuted
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
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
                if (route.routeDescription != null &&
                    route.routeDescription!.isNotEmpty &&
                    !_showRouteTimeline)
                  Entrance(
                    key: ValueKey('${route.id}_desc'),
                    index: sectionsToShow.length + 1,
                    child: Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                size: 18,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${route.routeName} Stops Summary :',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: context.colors.primary,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _showRouteTimeline = true),
                                icon: const Icon(Icons.map_outlined, size: 15),
                                label: const Text('Interactive Map',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            route.routeDescription!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Entrance(
                  key: ValueKey('${route.id}_bottom_google_map'),
                  index: sectionsToShow.length + 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 4),
                        child: Row(
                          children: [
                            Icon(Icons.map_rounded, color: context.colors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Interactive Route Map (Barishal City)',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: context.colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BusRouteInteractiveMap(
                        activeRouteId: route.id,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                    'Select Where You Want To Go',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                for (final p in _availablePlaces)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p),
                    selected: _selectedPlaceFilter == p,
                    selectedColor: context.colors.primary,
                    onTap: () {
                      setState(() => _selectedPlaceFilter = p);
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

class _LiveNextBusSpotlightCard extends StatelessWidget {
  final UniversityBusRoute route;
  final List<DepartureSection> sections;

  const _LiveNextBusSpotlightCard({
    required this.route,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty || sections.first.trips.isEmpty) {
      return const SizedBox.shrink();
    }

    final sec = sections.first;
    final trip = sec.trips.first;

    return GlassCard(
      gradient: context.isLight
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8F0FE), Color(0xFFFFFFFF)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x332E7DF6), Color(0x18141C2E)],
            ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 15, color: context.colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'NEXT DEPARTURE SPOTLIGHT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.colors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.directions_bus_filled_rounded,
                  color: context.colors.primary.withValues(alpha: 0.7), size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                trip.time,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leaving from: ${sec.departurePlace}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _BusNamePillTags(
                      busNameString: trip.busName,
                      isSmall: true,
                    ),
                  ],
                ),
              ),
              Pressable(
                onTap: () {
                  final tripId = _tripId(route.id, sec.departurePlace, trip.time);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => BusAlarmPickerModal(
                      tripId: tripId,
                      routeName: route.routeName,
                      departurePlace: sec.departurePlace,
                      tripTime: trip.time,
                      busName: trip.busName,
                    ),
                  ).then((result) {
                    if (!context.mounted) return;
                    if (result is ScheduledBusAlarmInfo) {
                      showToast(context, 'Alarm set for ${result.tripTime} (${result.leadMinutes} mins before)');
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.alarm_add_rounded,
                          size: 17, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Set Alarm',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                color:
                    isSelected ? context.colors.primary : context.colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 14,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? context.colors.primary
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
                  color:
                      isActive ? context.colors.primary : context.colors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 15,
                      color: isActive
                          ? context.colors.primary
                          : context.colors.textSecondary),
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
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isActive
                          ? context.colors.primary
                          : context.colors.textSecondary),
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
            color: isSelected ? context.colors.primary : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? context.colors.primary : context.colors.border,
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
              color: isSelected ? Colors.white : context.colors.textPrimary,
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
  final VoidCallback onTap;

  const _RouteButton({
    required this.routeName,
    required this.destinationHint,
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
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? context.colors.primary : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? context.colors.primary : context.colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                routeName,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (destinationHint.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(maxWidth: 130),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : context.colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    destinationHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.colors.primary,
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
    );
  }
}

class _BusNamePillTags extends StatelessWidget {
  final String busNameString;
  final bool isSmall;

  const _BusNamePillTags({required this.busNameString, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    final parts = busNameString
        .split(RegExp(r'[,/+]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: parts.map((name) {
        final isBrtc = name.toUpperCase().contains('BRTC') ||
            name.contains('বিআরটিসি');
        final tagColor = isBrtc ? context.colors.primary : context.colors.accentCyan;

        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 8 : 10, vertical: isSmall ? 3 : 5),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tagColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBrtc ? Icons.directions_bus_rounded : Icons.commute_rounded,
                size: isSmall ? 12 : 13.5,
                color: tagColor,
              ),
              const SizedBox(width: 5),
              Text(
                name,
                style: TextStyle(
                  color: tagColor,
                  fontWeight: FontWeight.w700,
                  fontSize: isSmall ? 11.5 : 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.14),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEPARTURE POINT',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                        color: context.colors.primary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      section.departurePlace,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${section.trips.length} Trips Scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
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
              trips: eveningTrips,
            ),
        ],
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
  final List<BusTripItem> trips;

  const _TripGroupSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.routeId,
    required this.routeName,
    required this.departurePlace,
    required this.trips,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(trips.length, (index) {
              final trip = trips[index];
              final isLast = index == trips.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 88),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  context.colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              trip.time,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _BusNamePillTags(busNameString: trip.busName),
                        ),
                        IconButton(
                          icon: const Icon(Icons.alarm_add_rounded, size: 20),
                          color: context.colors.primary,
                          tooltip: 'Set Alarm for ${trip.time}',
                          onPressed: () {
                            final tripId = _tripId(routeId, departurePlace, trip.time);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => BusAlarmPickerModal(
                                tripId: tripId,
                                routeName: routeName,
                                departurePlace: departurePlace,
                                tripTime: trip.time,
                                busName: trip.busName,
                              ),
                            ).then((result) {
                              if (!context.mounted) return;
                              if (result is ScheduledBusAlarmInfo) {
                                showToast(context, 'Alarm set for ${result.tripTime} (${result.leadMinutes} mins before)');
                              } else if (result == false) {
                                showToast(context, 'Alarm cancelled');
                              }
                            });
                          },
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
        const SizedBox(height: 6),
      ],
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary
                                        .withValues(alpha: 0.14),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(13)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on_rounded,
                                          size: 15,
                                          color: context.colors.primary),
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
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: context.colors.primary
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                                color: context
                                                    .colors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            _BusNamePillTags(
                                                busNameString: item['bus']!,
                                                isSmall: true),
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
