import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/map_lat_lng.dart';
import '../models/route_summary.dart';

/// OpenStreetMap 기반 OSRM 도보 경로 (API 키 불필요).
///
/// 기본: 공용 데모 서버 `router.project-osrm.org` (트래픽·정확도 제한 있음).
/// 프로덕션: `.env`에 `OSRM_BASE_URL`로 자체 호스팅 URL 지정 권장.
class OsrmDirectionsService {
  static const _defaultBase = 'https://router.project-osrm.org';

  static String get _baseUrl {
    final custom = Env.osrmBaseUrl.trim();
    if (custom.isEmpty) return _defaultBase;
    return custom.endsWith('/') ? custom.substring(0, custom.length - 1) : custom;
  }

  static Future<DirectionsResponse> fetchWalkingRoute({
    required MapLatLng origin,
    required MapLatLng destination,
  }) async {
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$_baseUrl/route/v1/foot/$coords').replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    try {
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'CampusLunch/1.0 (directions)'},
      );

      if (res.statusCode != 200) {
        return DirectionsResponse(
          apiStatus: 'HTTP_${res.statusCode}',
          errorMessage: res.body,
        );
      }

      return _parseBody(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      return DirectionsResponse(
        apiStatus: 'NETWORK_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  static DirectionsResponse _parseBody(Map<String, dynamic> body) {
    final code = body['code'] as String? ?? '';
    if (code != 'Ok') {
      return DirectionsResponse(
        apiStatus: code.isEmpty ? 'NO_ROUTES' : code.toUpperCase(),
        errorMessage: body['message'] as String?,
      );
    }

    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      return const DirectionsResponse(apiStatus: 'NO_ROUTES');
    }

    final route = routes.first as Map<String, dynamic>;
    final distance = (route['distance'] as num?)?.toDouble() ?? 0;

    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;
    if (coords == null || coords.isEmpty) {
      return const DirectionsResponse(apiStatus: 'NO_POLYLINE');
    }

    final points = <MapLatLng>[];
    for (final c in coords) {
      if (c is! List || c.length < 2) continue;
      final lng = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      points.add(MapLatLng(lat, lng));
    }

    if (points.length < 2) {
      return const DirectionsResponse(apiStatus: 'NO_POLYLINE');
    }

    return DirectionsResponse(
      apiStatus: 'OK',
      route: RouteSummary(
        points: points,
        distanceText: formatRouteDistance(distance.round()),
        durationText: formatWalkingDuration(distance.round()),
      ),
    );
  }
}
