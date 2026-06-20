import 'package:flutter/services.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../models/map_lat_lng.dart';

/// OSRM 등 외부 경로 좌표를 카카오맵 SDK Shape(Polyline)으로 그린다.
class KakaoRouteLine {
  static MethodChannel _channel(KakaoMapController controller) =>
      MethodChannel(
        'view.method_channel.kakao_maps_flutter#${controller.viewId}',
      );

  static Future<bool> set(
    KakaoMapController controller, {
    required List<MapLatLng> points,
    int color = 0xFF5E8C4A,
    int borderColor = 0xFF5E8C4A,
    double width = 5.0,
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
