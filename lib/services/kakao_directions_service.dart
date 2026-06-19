import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/map_lat_lng.dart';

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

/// 카카오 모빌리티 길찾기 API
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

    // 제휴 도보 API (KAKAO_MOBILITY_SERVICE 설정 시)
    if (Env.kakaoMobilityService.isNotEmpty) {
      final walking = await _requestRoute(
        key: key,
        path: '/affiliate/walking/v1/directions',
        query: query,
        extraHeaders: {'service': Env.kakaoMobilityService},
      );
      if (walking.isOk) return walking;
    }

    // fallback: 자동차 길찾기 (단거리 캠퍼스 내 보행 경로 근사)
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
    final duration = (summary?['duration'] as num?)?.toInt() ?? 0;

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
        distanceText: _formatDistance(distance),
        durationText: _formatDuration(duration),
      ),
    );
  }

  static RouteSummary estimateStraightWalkingRoute({
    required MapLatLng origin,
    required MapLatLng destination,
  }) {
    final meters = _haversineMeters(origin, destination);
    final minutes = (meters / 80).ceil().clamp(1, 999);

    return RouteSummary(
      points: [origin, destination],
      distanceText: _formatDistance(meters.round()),
      durationText: '약 $minutes분',
    );
  }

  static double _haversineMeters(MapLatLng a, MapLatLng b) {
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

  static double _degToRad(double deg) => deg * math.pi / 180;

  static String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds초';
    final mins = (seconds / 60).ceil();
    if (mins < 60) return '$mins분';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '$h시간 $m분' : '$h시간';
  }
}
