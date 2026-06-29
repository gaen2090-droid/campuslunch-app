import 'package:flutter/services.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../models/map_lat_lng.dart';

/// 카카오맵 경로선 스타일 (앱 전역)
abstract final class KakaoRouteLineStyle {
  /// 카카오맵 기본 경로선 톤 — 반투명 블루 + 짙은 테두리
  static const int color = 0xB84A7FE5;
  static const int borderColor = 0xFF3566B8;
  static const double width = 3.5;

  static const int estimatedColor = 0xB89CA3AF;
  static const int estimatedBorderColor = 0xFF6B7280;
  static const double estimatedWidth = 3.0;
}

/// OSRM 등 외부 경로 좌표를 카카오맵 SDK Shape(Polyline)으로 그린다.
class KakaoRouteLine {
  static MethodChannel _channel(KakaoMapController controller) =>
      MethodChannel(
        'view.method_channel.kakao_maps_flutter#${controller.viewId}',
      );

  static Future<bool> set(
    KakaoMapController controller, {
    required List<MapLatLng> points,
    int color = KakaoRouteLineStyle.color,
    int borderColor = KakaoRouteLineStyle.borderColor,
    double width = KakaoRouteLineStyle.width,
  }) async {
    if (points.length < 2) return false;

    final result = await _channel(controller).invokeMethod<bool>(
      'setRoutePolyline',
      {
        'points': points
            .map(
              (p) => {
                'latitude': p.latitude,
                'longitude': p.longitude,
              },
            )
            .toList(),
        'color': color,
        'borderColor': borderColor,
        'width': width,
      },
    );
    return result == true;
  }

  static Future<void> clear(KakaoMapController controller) async {
    await _channel(controller).invokeMethod<void>('clearRoutePolyline');
  }
}
