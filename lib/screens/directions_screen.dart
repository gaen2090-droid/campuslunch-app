import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/env.dart';
import '../models/map_lat_lng.dart';
import '../models/restaurant.dart';
import '../models/route_summary.dart';
import '../services/osrm_directions_service.dart';
import '../utils/kakao_map_ready.dart';
import '../utils/kakao_route_line.dart';

/// OSRM 도보 경로 + 카카오맵 SDK (polyline은 네이티브 Shape API)
class DirectionsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const DirectionsScreen({super.key, required this.restaurant});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  KakaoMapController? _controller;
  bool _mapReady = false;
  RouteSummary? _route;
  MapLatLng? _origin;
  String? _error;
  bool _loadingRoute = true;
  bool _isEstimatedRoute = false;

  MapLatLng get _destination => MapLatLng(
        widget.restaurant.latitude,
        widget.restaurant.longitude,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_loadRoute());
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      KakaoMarkerLayer.release(controller.viewId);
      unawaited(KakaoRouteLine.clear(controller));
      unawaited(removeMarkerQuietly(controller, id: 'route_origin'));
      unawaited(removeMarkerQuietly(controller, id: 'route_destination'));
    }
    super.dispose();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _loadingRoute = true;
      _error = null;
    });

    if (!widget.restaurant.hasMapLocation) {
      setState(() {
        _loadingRoute = false;
        _error = '매장 위치 정보가 없어요.';
      });
      return;
    }

    MapLatLng? origin;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      origin = MapLatLng(pos.latitude, pos.longitude);
    } catch (_) {
      origin = null;
    }

    if (origin == null) {
      setState(() {
        _loadingRoute = false;
        _error = '현재 위치를 확인할 수 없어요.\n위치 권한을 켜고 다시 시도해주세요.';
      });
      return;
    }

    final start = origin;
    final response = await OsrmDirectionsService.fetchWalkingRoute(
      origin: start,
      destination: _destination,
    );

    if (!mounted) return;

    if (response.isOk) {
      setState(() {
        _loadingRoute = false;
        _origin = start;
        _route = response.route;
        _isEstimatedRoute = false;
      });
    } else {
      debugPrint(
        '[Directions] OSRM failed: ${response.apiStatus} ${response.errorMessage}',
      );
      setState(() {
        _loadingRoute = false;
        _origin = start;
        _route = estimateStraightWalkingRoute(
          origin: start,
          destination: _destination,
        );
        _isEstimatedRoute = true;
      });
    }

    if (_mapReady) {
      unawaited(_setupMap());
    }
  }

  Future<void> _onMapCreated(KakaoMapController controller) async {
    _controller = controller;
    await runWhenKakaoMapReady(controller, () async {
      await ensureKakaoMarkerLayer(controller);
      if (!mounted) return;
      setState(() => _mapReady = true);
      await _setupMap();
    });
  }

  Future<void> _setupMap() async {
    final controller = _controller;
    final origin = _origin;
    final route = _route;
    if (controller == null || origin == null || route == null) return;

    await KakaoRouteLine.clear(controller);
    await removeMarkerQuietly(controller, id: 'route_origin');
    await removeMarkerQuietly(controller, id: 'route_destination');

    final lineColor = _isEstimatedRoute ? 0xFF9CA3AF : 0xFF5E8C4A;
    final borderColor = _isEstimatedRoute ? 0xFF9CA3AF : 0xFF5E8C4A;

    final drawn = await KakaoRouteLine.set(
      controller,
      points: route.points,
      color: lineColor,
      borderColor: borderColor,
    );
    if (!drawn) {
      debugPrint('[Directions] native route polyline failed');
    }

    await controller.addMarker(
      markerOption: MarkerOption(
        id: 'route_origin',
        latLng: LatLng(latitude: origin.latitude, longitude: origin.longitude),
        styleId: KakaoMarkerLayer.styleIdOrNull(controller, 'pin_my_location'),
        rank: 2,
        text: '내 위치',
      ),
    );
    await controller.addMarker(
      markerOption: MarkerOption(
        id: 'route_destination',
        latLng: LatLng(
          latitude: _destination.latitude,
          longitude: _destination.longitude,
        ),
        styleId: KakaoMarkerLayer.styleIdOrNull(controller, 'pin_destination'),
        rank: 2,
        text: widget.restaurant.name,
      ),
    );

    await _fitCameraToRoute(controller, route.points);
  }

  Future<void> _fitCameraToRoute(
    KakaoMapController controller,
    List<MapLatLng> points,
  ) async {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final zoom = _zoomForSpan(math.max(maxLat - minLat, maxLng - minLng));

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
    await controller.setZoomLevel(zoomLevel: zoom);
  }

  int _zoomForSpan(double span) {
    if (span > 0.3) return 10;
    if (span > 0.1) return 11;
    if (span > 0.05) return 12;
    if (span > 0.01) return 14;
    if (span > 0.003) return 16;
    if (span > 0.001) return 17;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final route = _route;
    final origin = _origin;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          r.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: Column(
        children: [
          if (route != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              color: const Color(0xFFF3F8F0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_walk,
                          size: 18, color: Color(0xFF4C9C2A)),
                      const SizedBox(width: 8),
                      Text(
                        '${route.durationText} · ${route.distanceText}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  if (_isEstimatedRoute) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'OSRM 경로를 불러오지 못해 직선 거리로 표시해요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.45,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    const Text(
                      '도보 경로 · OpenStreetMap 기반',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : origin == null || route == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF5E8C4A),
                        ),
                      )
                    : Stack(
                        children: [
                          if (Env.isKakaoMapConfigured)
                            KakaoMap(
                              onMapCreated: _onMapCreated,
                              initialPosition: LatLng(
                                latitude: _destination.latitude,
                                longitude: _destination.longitude,
                              ),
                              initialLevel: 16,
                              logo: const Logo(
                                alignment: LogoAlignment.bottomLeft,
                              ),
                            )
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  Env.hasKakaoNativeKey
                                      ? '카카오맵 SDK 초기화에 실패했어요.\n앱을 다시 실행해주세요.'
                                      : 'KAKAO_NATIVE_APP_KEY가 설정되지 않았어요.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          if (_loadingRoute || !_mapReady)
                            const ColoredBox(
                              color: Color(0x66FFFFFF),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF5E8C4A),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
