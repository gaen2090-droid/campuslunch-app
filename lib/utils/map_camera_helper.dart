import 'dart:math' as math;

import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../models/map_lat_lng.dart';

/// 카카오맵 카메라 — 경로 bounds 맞춤
class MapCameraHelper {
  static int zoomLevelForSpan(double latSpan, double lngSpan) {
    final span = math.max(latSpan, lngSpan);
    if (span <= 0.0015) return 18;
    if (span <= 0.003) return 17;
    if (span <= 0.006) return 16;
    if (span <= 0.012) return 15;
    if (span <= 0.025) return 14;
    if (span <= 0.05) return 13;
    return 12;
  }

  static ({
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  }) boundsFromPoints(Iterable<MapLatLng> points) {
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLng = double.infinity;
    var maxLng = -double.infinity;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    return (
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  static Future<void> fitRoute(
    KakaoMapController controller,
    List<MapLatLng> points, {
    double paddingRatio = 0.2,
  }) async {
    if (points.isEmpty) return;

    final bounds = boundsFromPoints(points);
    final latSpan = bounds.maxLat - bounds.minLat;
    final lngSpan = bounds.maxLng - bounds.minLng;
    final latPad = latSpan * paddingRatio;
    final lngPad = lngSpan * paddingRatio;

    final centerLat = (bounds.minLat + bounds.maxLat) / 2;
    final centerLng = (bounds.minLng + bounds.maxLng) / 2;
    final zoom = zoomLevelForSpan(latSpan + latPad * 2, lngSpan + lngPad * 2);

    await controller.setZoomLevel(zoomLevel: zoom);
    await controller.moveCamera(
      cameraUpdate: CameraUpdate.fromLatLng(
        LatLng(latitude: centerLat, longitude: centerLng),
      ),
      animation: const CameraAnimation(
        duration: 300,
        autoElevation: true,
        isConsecutive: false,
      ),
    );
  }
}
