import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Free, keyless walking-route lookup via the public OSRM instance hosted by
/// OpenStreetMap Germany (no Google billing account required). It's a shared
/// public demo service, not a guaranteed-uptime API, and route quality
/// depends on how well footpaths are mapped in OpenStreetMap for the area -
/// callers should fall back to a straight line when this returns null.
class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  Future<RouteResult?> getWalkingRoute(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      'https://routing.openstreetmap.de/routed-foot/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return null;

      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      final points = coordinates.map((c) {
        final pair = c as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();

      if (points.isEmpty) return null;

      return RouteResult(
        points: points,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
