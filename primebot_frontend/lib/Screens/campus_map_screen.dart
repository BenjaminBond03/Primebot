import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:primebot_frontend/data/campus_locations.dart';
import 'package:primebot_frontend/models/campus_location.dart';
import 'package:primebot_frontend/services/routing_service.dart';

const _primaryBlue = Color(0xFF1565C0);
const _darkText = Color(0xFF1A1A2E);
const _greyText = Color(0xFF757575);

enum _MapStyle { normal, satellite, terrain }

extension on _MapStyle {
  String get urlTemplate {
    switch (this) {
      case _MapStyle.normal:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _MapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapStyle.terrain:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  List<String> get subdomains =>
      this == _MapStyle.terrain ? const ['a', 'b', 'c'] : const [];

  String get attribution {
    switch (this) {
      case _MapStyle.normal:
        return 'OpenStreetMap contributors';
      case _MapStyle.satellite:
        return 'Esri World Imagery';
      case _MapStyle.terrain:
        return 'OpenTopoMap (CC-BY-SA)';
    }
  }
}

/// Sentinel returned by the route location picker to mean "use my current
/// location" as opposed to `null`, which means the picker was dismissed.
class _UseCurrentLocation {
  const _UseCurrentLocation();
}

const _useCurrentLocation = _UseCurrentLocation();

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController _mapController = MapController();
  String _query = '';
  LocationCategory? _categoryFilter;
  _MapStyle _mapStyle = _MapStyle.normal;

  bool _locationPermissionGranted = false;
  Position? _currentPosition;

  CampusLocation? _routeFrom;
  CampusLocation? _routeTo;

  List<LatLng>? _routePoints;
  String? _routeInfoLabel;
  bool _isRoutingLoading = false;
  CampusLocation? _activeRouteOrigin;
  CampusLocation? _activeRouteDestination;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final granted = await _ensureLocationPermission();
    if (!mounted) return;
    setState(() => _locationPermissionGranted = granted);
    if (!granted) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _currentPosition = position);
    } catch (_) {
      // Location unavailable; the map still works without a live fix.
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  List<CampusLocation> get _filtered {
    return sampleCampusLocations.where((loc) {
      final matchesQuery = _query.isEmpty ||
          loc.name.toLowerCase().contains(_query.toLowerCase());
      final matchesCategory =
          _categoryFilter == null || loc.category == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<Marker> get _markers {
    final markers = _filtered.map((loc) {
      return Marker(
        point: loc.position,
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showLocationDetails(loc),
          child: _buildMarkerIcon(loc.category),
        ),
      );
    }).toList();

    if (_locationPermissionGranted && _currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: _primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildMarkerIcon(LocationCategory category) {
    return Container(
      decoration: BoxDecoration(
        color: category.markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(category.icon, color: Colors.white, size: 18),
    );
  }

  void _focusLocation(CampusLocation loc) {
    _mapController.move(loc.position, 17);
  }

  Future<void> _recenterOnMe() async {
    if (_currentPosition == null) {
      await _initLocation();
    }
    if (_currentPosition == null || !mounted) return;
    _mapController.move(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      17,
    );
  }

  void _cycleMapType() {
    setState(() {
      _mapStyle = switch (_mapStyle) {
        _MapStyle.normal => _MapStyle.satellite,
        _MapStyle.satellite => _MapStyle.terrain,
        _MapStyle.terrain => _MapStyle.normal,
      };
    });
  }

  Future<void> _openDirections(CampusLocation loc) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${loc.position.latitude},${loc.position.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openRoute(CampusLocation? from, CampusLocation to) async {
    final destination = '${to.position.latitude},${to.position.longitude}';
    final uri = from == null
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destination')
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&origin=${from.position.latitude},${from.position.longitude}'
            '&destination=$destination',
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showRouteTo(CampusLocation destination, {CampusLocation? origin}) async {
    final originPoint = origin?.position ??
        (_currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : null);

    if (originPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable location access, or pick a starting point, to get directions.'),
        ),
      );
      return;
    }

    setState(() {
      _isRoutingLoading = true;
      _activeRouteOrigin = origin;
      _activeRouteDestination = destination;
      _routeInfoLabel = null;
    });

    final result = await RoutingService.instance.getWalkingRoute(originPoint, destination.position);
    if (!mounted) return;

    setState(() {
      _isRoutingLoading = false;
      if (result != null) {
        _routePoints = result.points;
        _routeInfoLabel =
            '${_formatDistance(result.distanceMeters)} · ${_formatDuration(result.durationSeconds)} walk';
      } else {
        _routePoints = [originPoint, destination.position];
        _routeInfoLabel =
            'Approx. ${_distanceLabel(originPoint, destination.position)} · straight line (live routing unavailable)';
      }
    });

    _fitRouteBounds();
  }

  void _fitRouteBounds() {
    final points = _routePoints;
    if (points == null || points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(40, 140, 40, 260),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints = null;
      _routeInfoLabel = null;
      _activeRouteOrigin = null;
      _activeRouteDestination = null;
    });
  }

  String _formatDistance(double meters) {
    return meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 1) return '<1 min';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  String _distanceLabel(LatLng a, LatLng b) {
    final meters = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    return meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: campusCenter,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyle.urlTemplate,
                subdomains: _mapStyle.subdomains,
                userAgentPackageName: 'com.example.primebot_frontend',
              ),
              if (_routePoints != null)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints!, color: _primaryBlue, strokeWidth: 5),
                  ],
                ),
              MarkerLayer(markers: _markers),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    _mapStyle.attribution,
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 10),
                _buildCategoryChips(),
                if (_routePoints != null || _isRoutingLoading) ...[
                  const SizedBox(height: 10),
                  _buildRouteBanner(),
                ],
              ],
            ),
          ),
          _buildMapControls(),
          _buildLocationSheet(),
        ],
      ),
    );
  }

  Widget _buildRouteBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_walk_rounded, color: _primaryBlue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: _isRoutingLoading
                  ? const Text(
                      'Finding route...',
                      style: TextStyle(fontSize: 13, color: _greyText),
                    )
                  : Text(
                      _routeInfoLabel ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _darkText,
                      ),
                    ),
            ),
            if (!_isRoutingLoading && _activeRouteDestination != null)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18, color: _primaryBlue),
                tooltip: 'Open in Google Maps',
                onPressed: () => _openRoute(_activeRouteOrigin, _activeRouteDestination!),
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: _greyText),
              tooltip: 'Clear route',
              onPressed: _clearRoute,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 250,
      child: Column(
        children: [
          _buildControlButton(
            icon: switch (_mapStyle) {
              _MapStyle.satellite => Icons.satellite_alt_rounded,
              _MapStyle.terrain => Icons.terrain_rounded,
              _MapStyle.normal => Icons.layers_outlined,
            },
            tooltip: 'Map type',
            onTap: _cycleMapType,
          ),
          const SizedBox(height: 10),
          _buildControlButton(
            icon: Icons.alt_route_rounded,
            tooltip: 'Plan a route',
            onTap: _showRoutePlanner,
          ),
          const SizedBox(height: 10),
          _buildControlButton(
            icon: Icons.my_location_rounded,
            tooltip: 'My location',
            onTap: _recenterOnMe,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: _primaryBlue, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: _greyText, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search campus locations...',
                  hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip(label: 'All', selected: _categoryFilter == null, onTap: () {
            setState(() => _categoryFilter = null);
          }),
          const SizedBox(width: 8),
          ...LocationCategory.values.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                label: cat.label,
                icon: cat.icon,
                selected: _categoryFilter == cat,
                onTap: () => setState(
                  () => _categoryFilter = _categoryFilter == cat ? null : cat,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : _greyText),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.16,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        final locations = _filtered;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 16),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                '${locations.length} location${locations.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _greyText,
                ),
              ),
              const SizedBox(height: 12),
              if (locations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'No locations match your search.',
                      style: TextStyle(color: _greyText, fontSize: 14),
                    ),
                  ),
                )
              else
                ...locations.map(_buildLocationCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationCard(CampusLocation loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: GestureDetector(
        onTap: () => _focusLocation(loc),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(loc.category.icon, color: _primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loc.description,
                    style: const TextStyle(fontSize: 12, color: _greyText, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showRouteTo(loc),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Go',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showLocationDetails(CampusLocation loc) {
    _focusLocation(loc);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: loc.category.markerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(loc.category.icon, color: loc.category.markerColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.category.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: loc.category.markerColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              loc.description,
              style: const TextStyle(fontSize: 14, color: _greyText, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showRouteTo(loc);
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openDirections(loc);
                },
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text(
                  'Open in Google Maps instead',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoutePlanner() {
    _routeFrom = null;
    _routeTo = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) => _buildRoutePlannerSheet(setSheetState),
        );
      },
    );
  }

  Widget _buildRoutePlannerSheet(StateSetter setSheetState) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan a Route',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText),
            ),
            const SizedBox(height: 16),
            _buildRouteField(
              label: 'From',
              value: _routeFrom?.name ?? 'My Current Location',
              onTap: () => _pickRouteLocation(setSheetState, isFrom: true),
            ),
            const SizedBox(height: 12),
            _buildRouteField(
              label: 'To',
              value: _routeTo?.name ?? 'Select a location',
              onTap: () => _pickRouteLocation(setSheetState, isFrom: false),
            ),
            const SizedBox(height: 16),
            if (_routeTo != null)
              Text(_routeDistanceLabel(), style: const TextStyle(fontSize: 13, color: _greyText)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _routeTo == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _showRouteTo(_routeTo!, origin: _routeFrom);
                      },
                icon: const Icon(Icons.directions),
                label: const Text('Show Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_routeTo != null)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openRoute(_routeFrom, _routeTo!);
                  },
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text(
                    'Open in Google Maps instead',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: _greyText, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 14, color: _darkText, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _greyText),
          ],
        ),
      ),
    );
  }

  String _routeDistanceLabel() {
    if (_routeTo == null) return '';

    final fromPosition = _routeFrom?.position ??
        (_currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : null);

    if (fromPosition == null) return 'Distance unavailable (no location access)';
    return 'Approx. ${_distanceLabel(fromPosition, _routeTo!.position)} in a straight line';
  }

  Future<void> _pickRouteLocation(StateSetter setSheetState, {required bool isFrom}) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (isFrom)
              ListTile(
                leading: const Icon(Icons.my_location, color: _primaryBlue),
                title: const Text('My Current Location'),
                onTap: () => Navigator.pop(context, _useCurrentLocation),
              ),
            ...sampleCampusLocations.map(
              (loc) => ListTile(
                leading: Icon(loc.category.icon, color: _primaryBlue),
                title: Text(loc.name),
                onTap: () => Navigator.pop(context, loc),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setSheetState(() {
      if (isFrom) {
        _routeFrom = result is CampusLocation ? result : null;
      } else if (result is CampusLocation) {
        _routeTo = result;
      }
    });
  }
}
