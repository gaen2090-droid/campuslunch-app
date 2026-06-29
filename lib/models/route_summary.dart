import 'dart:math' as math;

import 'map_lat_lng.dart';

class RouteSummary {
  final List<MapLatLng> points;
  final String distanceText;
  final String durationText;

  const RouteSummary({
    required this.points,
    required this.distanceText,
    required this.durationText,
  });
}

class DirectionsResponse {
  final RouteSummary? route;
  final String apiStatus;
  final String? errorMessage;

  const DirectionsResponse({
    required this.apiStatus,
    this.route,
    this.errorMessage,
  });

  bool get isOk => apiStatus == 'OK' && route != null;
}

/// 도보 4.8 km/h (= 80 m/분) 기준 소요 시간
String formatWalkingDuration(int distanceMeters) {
  const metersPerMinute = 80.0;
  final minutes = (distanceMeters / metersPerMinute).ceil().clamp(1, 999);
  if (minutes < 60) return '약 $minutes분';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m > 0 ? '약 $h시간 $m분' : '약 $h시간';
}

RouteSummary estimateStraightWalkingRoute({
  required MapLatLng origin,
  required MapLatLng destination,
}) {
  final meters = _haversineMeters(origin, destination).round();

  return RouteSummary(
    points: [origin, destination],
    distanceText: formatRouteDistance(meters),
    durationText: formatWalkingDuration(meters),
  );
}

double _haversineMeters(MapLatLng a, MapLatLng b) {
  const r = 6371000.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.asin(math.sqrt(h));
}

double _degToRad(double deg) => deg * math.pi / 180;

String formatRouteDistance(int meters) {
  if (meters < 1000) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// OSRM 등 API duration(초) — 레거시. 도보 UI는 [formatWalkingDuration] 사용.
String formatRouteDuration(int seconds) {
  if (seconds < 60) return '$seconds초';
  final mins = (seconds / 60).ceil();
  if (mins < 60) return '$mins분';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m > 0 ? '$h시간 $m분' : '$h시간';
}
