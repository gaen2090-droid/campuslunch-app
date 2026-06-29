import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/campus.dart';
import '../models/map_lat_lng.dart';

/// 지도 카메라를 좌표 목록에 맞추는 유틸 (Mercator bounds → 최대 확대)
abstract final class MapCameraFit {
  static const _animation = CameraAnimation(
    duration: 350,
    autoElevation: true,
    isConsecutive: false,
  );

  /// 카카오맵 줌 스케일이 Web Mercator 공식보다 약 1레벨 넓게 보이는 경향 보정
  static const _kakaoZoomBias = 1;

  static Future<void> moveToFit(
    KakaoMapController controller,
    List<MapLatLng> points, {
    double paddingFraction = 0.05,
    int minZoom = 11,
    int maxZoom = 19,
    bool animate = true,
    bool campusBoundsOnly = false,
    Size? viewportSize,
    EdgeInsets viewportPadding = EdgeInsets.zero,
  }) async {
    final latLngs = points
        .map((p) => LatLng(latitude: p.latitude, longitude: p.longitude))
        .toList();
    await moveToFitLatLngs(
      controller,
      latLngs,
      paddingFraction: paddingFraction,
      minZoom: minZoom,
      maxZoom: maxZoom,
      animate: animate,
      campusBoundsOnly: campusBoundsOnly,
      viewportSize: viewportSize,
      viewportPadding: viewportPadding,
    );
  }

  static Future<void> moveToFitLatLngs(
    KakaoMapController controller,
    List<LatLng> points, {
    double paddingFraction = 0.05,
    int minZoom = 11,
    int maxZoom = 19,
    bool animate = true,
    bool campusBoundsOnly = false,
    Size? viewportSize,
    EdgeInsets viewportPadding = EdgeInsets.zero,
  }) async {
    final filtered = campusBoundsOnly
        ? points
            .where(
              (p) => Campus.containsLatLng(p.latitude, p.longitude),
            )
            .toList()
        : points;
    final target = filtered.isNotEmpty ? filtered : points;

    if (target.isEmpty) {
      return;
    }

    final viewW = math.max(
      120.0,
      (viewportSize?.width ?? 390) - viewportPadding.horizontal,
    );
    final viewH = math.max(
      120.0,
      (viewportSize?.height ?? 640) - viewportPadding.vertical,
    );

    if (target.length == 1) {
      await _moveCenterAndZoom(
        controller,
        target.first,
        math.min(18, maxZoom).clamp(minZoom, maxZoom),
        animate: animate,
      );
      return;
    }

    var minLat = target.first.latitude;
    var maxLat = target.first.latitude;
    var minLng = target.first.longitude;
    var maxLng = target.first.longitude;

    for (final p in target) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    // 한 점에 몰린 구역도 과도한 줌 방지용 최소 span
    const minSpan = 0.00012;
    if (maxLat - minLat < minSpan) {
      final mid = (maxLat + minLat) / 2;
      minLat = mid - minSpan / 2;
      maxLat = mid + minSpan / 2;
    }
    if (maxLng - minLng < minSpan) {
      final mid = (maxLng + minLng) / 2;
      minLng = mid - minSpan / 2;
      maxLng = mid + minSpan / 2;
    }

    final latPad = (maxLat - minLat) * paddingFraction;
    final lngPad = (maxLng - minLng) * paddingFraction;
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final zoom = boundsZoomLevel(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      mapWidthPx: viewW,
      mapHeightPx: viewH,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    await _moveCenterAndZoom(
      controller,
      LatLng(latitude: centerLat, longitude: centerLng),
      zoom,
      animate: animate,
    );
  }

  static Future<void> _moveCenterAndZoom(
    KakaoMapController controller,
    LatLng center,
    int zoom, {
    required bool animate,
  }) async {
    await controller.moveCamera(
      cameraUpdate: CameraUpdate(
        position: center,
        zoomLevel: zoom,
      ),
      animation: animate ? _animation : null,
    );
  }

  /// Google Maps bounds zoom 알고리즘 (Mercator)
  static int boundsZoomLevel({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required double mapWidthPx,
    required double mapHeightPx,
    int minZoom = 11,
    int maxZoom = 19,
  }) {
    const worldDim = 256.0;

    final latFraction =
        (_latRad(maxLat) - _latRad(minLat)).abs() / math.pi;
    var lngDiff = maxLng - minLng;
    if (lngDiff < 0) lngDiff += 360;
    final lngFraction = lngDiff / 360;

    final latZoom = _zoomForFraction(mapHeightPx, worldDim, latFraction);
    final lngZoom = _zoomForFraction(mapWidthPx, worldDim, lngFraction);
    final raw = math.min(latZoom, lngZoom) + _kakaoZoomBias;

    return raw.clamp(minZoom, maxZoom);
  }

  static int _zoomForFraction(
    double mapPx,
    double worldPx,
    double fraction,
  ) {
    if (fraction <= 0 || mapPx <= 0) return 21;
    final zoom = math.log(mapPx / worldPx / fraction) / math.ln2;
    if (zoom.isNaN || zoom.isInfinite) return 21;
    return zoom.floor();
  }

  static double _latRad(double lat) {
    final sin = math.sin(lat * math.pi / 180);
    final clamped = sin.clamp(-0.9999, 0.9999);
    final radX2 = math.log((1 + clamped) / (1 - clamped)) / 2;
    return radX2.clamp(-math.pi, math.pi) / 2;
  }
}

/// 네이티브 polyline/카메라용 경로 좌표 간소화
List<MapLatLng> simplifyRoutePoints(
  List<MapLatLng> points, {
  int maxPoints = 400,
}) {
  if (points.length <= maxPoints) return points;
  final step = (points.length / maxPoints).ceil().clamp(1, points.length);
  final sampled = <MapLatLng>[];
  for (var i = 0; i < points.length; i += step) {
    sampled.add(points[i]);
  }
  final last = points.last;
  if (sampled.last != last) sampled.add(last);
  return sampled;
}

/// 카메라 bounds용 — 전체 경로 min/max만 필요할 때
List<MapLatLng> boundsSampleFromRoute(
  List<MapLatLng> points, {
  int maxPoints = 80,
}) {
  if (points.length <= maxPoints) return points;
  final sampled = simplifyRoutePoints(points, maxPoints: maxPoints - 2);
  return sampled;
}
