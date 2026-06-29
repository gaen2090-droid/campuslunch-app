import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/campus.dart';
import '../models/map_lat_lng.dart';

/// 지도 카메라 맞춤 프로필
enum CameraFitProfile {
  /// 중문·후문 등 — 마커·라벨 여유 (기본)
  balanced,
  /// 정문 단독 — 조금 더 확대 (이전 tight 프로필)
  tight,
}

class CameraFitOptions {
  final double paddingFraction;
  final int maxZoom;
  final bool includeMarkerGraphics;
  final double minSpanDegrees;
  final int zoomBias;
  final EdgeInsets viewportPadding;

  const CameraFitOptions({
    required this.paddingFraction,
    required this.maxZoom,
    required this.includeMarkerGraphics,
    required this.minSpanDegrees,
    required this.zoomBias,
    required this.viewportPadding,
  });

  static CameraFitOptions forProfile(CameraFitProfile profile) {
    return switch (profile) {
      CameraFitProfile.tight => const CameraFitOptions(
          paddingFraction: 0.04,
          maxZoom: 19,
          includeMarkerGraphics: false,
          minSpanDegrees: 0.00012,
          zoomBias: 1,
          viewportPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      CameraFitProfile.balanced => const CameraFitOptions(
          paddingFraction: 0.08,
          maxZoom: 18,
          includeMarkerGraphics: true,
          minSpanDegrees: 0.00028,
          zoomBias: 0,
          viewportPadding: EdgeInsets.fromLTRB(40, 56, 40, 44),
        ),
    };
  }
}

/// 지도 카메라를 좌표 목록에 맞추는 유틸 (Mercator bounds + 마커·라벨 여유)
abstract final class MapCameraFit {
  static const _animation = CameraAnimation(
    duration: 350,
    autoElevation: true,
    isConsecutive: false,
  );

  /// 핀(72×88) + 식당명 라벨이 잘리지 않도록 좌표 bounds 바깥으로 확장 (도, 캠퍼스 규모)
  static const _pinPadNorth = 0.00052;
  static const _pinPadSouth = 0.00008;
  static const _pinPadSide = 0.00034;

  static Future<void> moveToFit(
    KakaoMapController controller,
    List<MapLatLng> points, {
    CameraFitProfile profile = CameraFitProfile.balanced,
    double? paddingFraction,
    int minZoom = 11,
    int? maxZoom,
    bool animate = true,
    bool campusBoundsOnly = false,
    Size? viewportSize,
    EdgeInsets? viewportPadding,
    bool? includeMarkerGraphics,
  }) async {
    final latLngs = points
        .map((p) => LatLng(latitude: p.latitude, longitude: p.longitude))
        .toList();
    await moveToFitLatLngs(
      controller,
      latLngs,
      profile: profile,
      paddingFraction: paddingFraction,
      minZoom: minZoom,
      maxZoom: maxZoom,
      animate: animate,
      campusBoundsOnly: campusBoundsOnly,
      viewportSize: viewportSize,
      viewportPadding: viewportPadding,
      includeMarkerGraphics: includeMarkerGraphics,
    );
  }

  static Future<void> moveToFitLatLngs(
    KakaoMapController controller,
    List<LatLng> points, {
    CameraFitProfile profile = CameraFitProfile.balanced,
    double? paddingFraction,
    int minZoom = 11,
    int? maxZoom,
    bool animate = true,
    bool campusBoundsOnly = false,
    Size? viewportSize,
    EdgeInsets? viewportPadding,
    bool? includeMarkerGraphics,
  }) async {
    final opts = CameraFitOptions.forProfile(profile);
    final padFraction = paddingFraction ?? opts.paddingFraction;
    final zoomMax = maxZoom ?? opts.maxZoom;
    final edgePad = viewportPadding ?? opts.viewportPadding;
    final markerPad = includeMarkerGraphics ?? opts.includeMarkerGraphics;
    final minSpan = opts.minSpanDegrees;
    final zoomBias = opts.zoomBias;
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
      (viewportSize?.width ?? 390) - edgePad.horizontal,
    );
    final viewH = math.max(
      120.0,
      (viewportSize?.height ?? 640) - edgePad.vertical,
    );

    if (target.length == 1) {
      await _moveCenterAndZoom(
        controller,
        target.first,
        math.min(17, zoomMax).clamp(minZoom, zoomMax),
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

    // 좌표만 겹친 경우 과확대 방지
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

    final latPad = (maxLat - minLat) * padFraction;
    final lngPad = (maxLng - minLng) * padFraction;
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    if (markerPad) {
      minLat -= _pinPadSouth;
      maxLat += _pinPadNorth;
      minLng -= _pinPadSide;
      maxLng += _pinPadSide;
    }

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
      maxZoom: zoomMax,
      zoomBias: zoomBias,
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

  /// Google Maps bounds zoom (Mercator). floor → 이론상 들어가는 최대 정수 줌.
  static int boundsZoomLevel({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required double mapWidthPx,
    required double mapHeightPx,
    int minZoom = 11,
    int maxZoom = 19,
    int zoomBias = 0,
  }) {
    const worldDim = 256.0;

    final latFraction =
        (_latRad(maxLat) - _latRad(minLat)).abs() / math.pi;
    var lngDiff = maxLng - minLng;
    if (lngDiff < 0) lngDiff += 360;
    final lngFraction = lngDiff / 360;

    final latZoom = _zoomForFraction(mapHeightPx, worldDim, latFraction);
    final lngZoom = _zoomForFraction(mapWidthPx, worldDim, lngFraction);

    return (math.min(latZoom, lngZoom) + zoomBias).clamp(minZoom, maxZoom);
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

/// 카메라 bounds용 — 경로 꺾임 포함 min/max (샘플링)
List<MapLatLng> boundsSampleFromRoute(
  List<MapLatLng> points, {
  int maxPoints = 80,
}) {
  if (points.length <= maxPoints) return points;
  final sampled = simplifyRoutePoints(points, maxPoints: maxPoints - 2);
  return sampled;
}
