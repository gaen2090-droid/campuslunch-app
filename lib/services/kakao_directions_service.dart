import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/map_lat_lng.dart';
import '../models/route_summary.dart';

export '../models/route_summary.dart';

/// 카카오 모빌리티 길찾기 API (레거시 — 앱 길찾기는 OSRM 사용)
class KakaoDirectionsService {
  static const _host = 'apis-navi.kakaomobility.com';

  static Future<DirectionsResponse> fetchWalkingRoute({
    required MapLatLng origin,
    required MapLatLng destination,
  }) async {
    final key = Env.kakaoRestApiKey;
    if (key.isEmpty) {
      return const DirectionsResponse(apiStatus: 'MISSING_API_KEY');
    }

    final query = {
      'origin': '${origin.longitude},${origin.latitude}',
      'destination': '${destination.longitude},${destination.latitude}',
      'priority': 'DISTANCE',
      'summary': 'false',
    };

    if (Env.kakaoMobilityService.isNotEmpty) {
      final walking = await _requestRoute(
        key: key,
        path: '/affiliate/walking/v1/directions',
        query: query,
        extraHeaders: {'service': Env.kakaoMobilityService},
      );
      if (walking.isOk) return walking;
    }

    return _requestRoute(
      key: key,
      path: '/v1/directions',
      query: query,
    );
  }

  static Future<DirectionsResponse> _requestRoute({
    required String key,
    required String path,
    required Map<String, String> query,
    Map<String, String> extraHeaders = const {},
  }) async {
    final uri = Uri.https(_host, path, query);

    try {
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $key',
          ...extraHeaders,
        },
      );

      if (res.statusCode != 200) {
        return DirectionsResponse(
          apiStatus: 'HTTP_${res.statusCode}',
          errorMessage: res.body,
        );
      }

      return _parseRouteBody(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      return DirectionsResponse(
        apiStatus: 'NETWORK_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  static DirectionsResponse _parseRouteBody(Map<String, dynamic> body) {
    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      return DirectionsResponse(
        apiStatus: body['code'] as String? ?? 'NO_ROUTES',
        errorMessage: body['msg'] as String?,
      );
    }

    final route = routes.first as Map<String, dynamic>;
    final resultCode = route['result_code'];
    if (resultCode != null && resultCode != 0) {
      return DirectionsResponse(
        apiStatus: 'ROUTE_$resultCode',
        errorMessage: (route['result_msg'] ?? route['result_message']) as String?,
      );
    }

    final summary = route['summary'] as Map<String, dynamic>?;
    final distance = (summary?['distance'] as num?)?.toInt() ?? 0;

    final points = <MapLatLng>[];
    final sections = route['sections'] as List? ?? [];
    for (final section in sections) {
      if (section is! Map) continue;
      final roads = section['roads'] as List? ?? [];
      for (final road in roads) {
        if (road is! Map) continue;
        final vertexes = road['vertexes'] as List?;
        if (vertexes == null) continue;
        for (var i = 0; i + 1 < vertexes.length; i += 2) {
          final lng = (vertexes[i] as num).toDouble();
          final lat = (vertexes[i + 1] as num).toDouble();
          points.add(MapLatLng(lat, lng));
        }
      }
    }

    if (points.isEmpty) {
      return const DirectionsResponse(apiStatus: 'NO_POLYLINE');
    }

    return DirectionsResponse(
      apiStatus: 'OK',
      route: RouteSummary(
        points: points,
        distanceText: formatRouteDistance(distance),
        durationText: formatWalkingDuration(distance),
      ),
    );
  }
}
