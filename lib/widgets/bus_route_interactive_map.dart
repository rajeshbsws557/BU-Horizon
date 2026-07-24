// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/bus_route_coordinates.dart';
import '../theme/app_theme.dart';
import 'horizon_logo.dart';

class BusRouteInteractiveMap extends StatefulWidget {
  final String? activeRouteId;
  final ValueChanged<String?>? onRouteSelected;
  final VoidCallback? onClose;

  const BusRouteInteractiveMap({
    super.key,
    this.activeRouteId,
    this.onRouteSelected,
    this.onClose,
  });

  @override
  State<BusRouteInteractiveMap> createState() => _BusRouteInteractiveMapState();
}

class _BusRouteInteractiveMapState extends State<BusRouteInteractiveMap> {
  late final MapController _mapController;
  late String? _selectedRouteId;
  BusStopLocation? _selectedStop;
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedRouteId = widget.activeRouteId;
  }

  @override
  void didUpdateWidget(covariant BusRouteInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRouteId != widget.activeRouteId) {
      setState(() {
        _selectedRouteId = widget.activeRouteId;
      });
    }
  }

  void _recenterOnCampus() {
    _mapController.move(BarishalBusRouteCoordinates.buCampusPoint, 13.5);
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tile URL: Google Maps vector tiles or CartoDB Dark for clean high-contrast
    final String tileUrl = _isSatellite
        ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
        : isDark
            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
            : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

    final List<Polyline> polylines = [];
    final Map<String, BusStopLocation> uniqueStopsMap = {};

    for (final route in BarishalBusRouteCoordinates.allRoutes) {
      final isHighlighted = _selectedRouteId == null ||
          _selectedRouteId == 'all' ||
          route.routeId == _selectedRouteId;

      if (isHighlighted) {
        polylines.add(
          Polyline(
            points: route.pathPoints,
            strokeWidth: route.routeId == _selectedRouteId ? 5.5 : 4.0,
            color: route.color.withValues(alpha: route.routeId == _selectedRouteId ? 1.0 : 0.75),
          ),
        );
      }

      for (final stop in route.keyStops) {
        uniqueStopsMap[stop.id] = stop;
      }
    }

    final markers = <Marker>[];
    for (final stop in uniqueStopsMap.values) {
      final isCampus = stop.id == 'bu_campus';
      final isSelectedStop = _selectedStop?.id == stop.id;

      markers.add(
        Marker(
          point: stop.point,
          width: isCampus ? 44 : 34,
          height: isCampus ? 44 : 34,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedStop = stop;
              });
              _mapController.move(stop.point, 14.5);
            },
            child: AnimatedScale(
              scale: isSelectedStop ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: isCampus
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.primary.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: HorizonLogo(size: 24),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelectedStop
                            ? context.colors.primary
                            : context.colors.surfaceAlt,
                        border: Border.all(
                          color: isSelectedStop
                              ? Colors.white
                              : context.colors.primary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        size: 17,
                        color: isSelectedStop
                            ? Colors.white
                            : context.colors.primary,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            // 1. Google Maps Engine / Vector Tile Map Canvas
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: BarishalBusRouteCoordinates.buCampusPoint,
                initialZoom: 12.5,
                minZoom: 10.0,
                maxZoom: 17.5,
                onTap: (_, __) {
                  setState(() => _selectedStop = null);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'dev.rajeshbiswas.bu_horizon',
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),

            // 2. Top Header Bar: Route Selector Pills & Close Action
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _RouteFilterPill(
                            label: 'All Routes',
                            color: context.colors.primary,
                            isSelected: _selectedRouteId == null || _selectedRouteId == 'all',
                            onTap: () {
                              setState(() => _selectedRouteId = 'all');
                              widget.onRouteSelected?.call('all');
                              _recenterOnCampus();
                            },
                          ),
                          for (final route in BarishalBusRouteCoordinates.allRoutes)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _RouteFilterPill(
                                label: route.routeName,
                                color: route.color,
                                isSelected: _selectedRouteId == route.routeId,
                                onTap: () {
                                  setState(() => _selectedRouteId = route.routeId);
                                  widget.onRouteSelected?.call(route.routeId);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onClose != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onClose,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 3. Right Map Controls Overlay (Recenter, Zoom, Layer)
            Positioned(
              right: 10,
              bottom: _selectedStop != null ? 110 : 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapOverlayIconButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Recenter on BU Campus',
                    onTap: _recenterOnCampus,
                  ),
                  const SizedBox(height: 6),
                  _MapOverlayIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom In',
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 6),
                  _MapOverlayIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom Out',
                    onTap: _zoomOut,
                  ),
                  const SizedBox(height: 6),
                  _MapOverlayIconButton(
                    icon: _isSatellite ? Icons.map_rounded : Icons.layers_rounded,
                    tooltip: _isSatellite ? 'Standard View' : 'Satellite View',
                    onTap: () => setState(() => _isSatellite = !_isSatellite),
                  ),
                ],
              ),
            ),

            // 4. Selected Stop Info Popup Sheet
            if (_selectedStop != null)
              Positioned(
                left: 10,
                right: 56,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.place_rounded,
                          size: 18,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStop!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedStop!.description,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.colors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _selectedStop = null),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteFilterPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteFilterPill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : context.colors.surfaceAlt.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : context.colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : context.colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapOverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapOverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: context.colors.primary),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
}
