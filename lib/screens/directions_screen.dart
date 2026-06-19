import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/env.dart';
import '../models/map_lat_lng.dart';
import '../models/restaurant.dart';
import '../services/kakao_directions_service.dart';
import '../utils/kakao_map_launcher.dart';
import '../utils/kakao_map_ready.dart';
import '../utils/map_camera_helper.dart';
import '../utils/map_marker_icons.dart';
import '../widgets/route_polyline_overlay.dart';

/// 앱 내 카카오맵 길찾기 (모빌리티 API 도보 경로 + polyline)
class DirectionsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const DirectionsScreen({super.key, required this.restaurant});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  KakaoMapController? _controller;
  RouteSummary? _route;
  MapLatLng? _origin;
  String? _error;
  bool _loading = true;
  bool _mapReady = false;
  bool _isEstimatedRoute = false;

  MapLatLng get _destination => MapLatLng(
        widget.restaurant.latitude,
        widget.restaurant.longitude,
      );

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _loading = true;
      _error = null;
      _mapReady = false;
    });

    if (!Env.isKakaoLocalConfigured) {
      setState(() {
        _loading = false;
        _error = 'KAKAO_REST_API_KEY가 설정되지 않았어요.';
      });
      return;
    }

    if (!widget.restaurant.hasMapLocation) {
      setState(() {
        _loading = false;
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
        _loading = false;
        _error = '현재 위치를 확인할 수 없어요.\n위치 권한을 켜고 다시 시도해주세요.';
      });
      return;
    }

    final start = origin;
    final response = await KakaoDirectionsService.fetchWalkingRoute(
      origin: start,
      destination: _destination,
    );

    if (!mounted) return;

    if (response.isOk) {
      setState(() {
        _loading = false;
        _origin = start;
        _route = response.route;
        _isEstimatedRoute = false;
      });
      _trySetupMap();
      return;
    }

    setState(() {
      _loading = false;
      _origin = start;
      _route = KakaoDirectionsService.estimateStraightWalkingRoute(
        origin: start,
        destination: _destination,
      );
      _isEstimatedRoute = true;
    });
    _trySetupMap();
  }

  void _trySetupMap() {
    if (_controller == null || _origin == null || _route == null) return;
    unawaited(_setupMap());
  }

  Future<void> _setupMap() async {
    final controller = _controller;
    final origin = _origin;
    final route = _route;
    if (controller == null || origin == null || route == null) return;

    await runWhenKakaoMapReady(controller, () async {
      await ensureKakaoMarkerLayer(controller);

      await controller.removeMarker(id: 'destination');
      await controller.removeMarker(id: 'origin');

      await controller.addMarker(
        markerOption: MarkerOption(
          id: 'destination',
          latLng: LatLng(
            latitude: _destination.latitude,
            longitude: _destination.longitude,
          ),
          styleId: KakaoMarkerLayer.styleIdOrNull(
            MapMarkerIcons.styleIdForStatus('자리없음'),
          ),
          rank: 2,
          text: widget.restaurant.name,
        ),
      );
      await controller.addMarker(
        markerOption: MarkerOption(
          id: 'origin',
          latLng: LatLng(
            latitude: origin.latitude,
            longitude: origin.longitude,
          ),
          styleId: KakaoMarkerLayer.styleIdOrNull('pin_my_location'),
          rank: 2,
          text: '내 위치',
        ),
      );

      await MapCameraHelper.fitRoute(controller, route.points);

      if (!mounted) return;
      setState(() => _mapReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final route = _route;

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
                      '정확한 도보 경로를 불러오지 못해 직선 거리로 표시해요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _origin == null
                          ? null
                          : () => openKakaoMapWalkingRoute(
                                origin: _origin!,
                                destination: _destination,
                              ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        '카카오맵에서 길찾기',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5E8C4A)),
                  )
                : _error != null
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
                    : Stack(
                        children: [
                          KakaoMap(
                            onMapCreated: (c) {
                              _controller = c;
                              _trySetupMap();
                            },
                            initialPosition: LatLng(
                              latitude: _destination.latitude,
                              longitude: _destination.longitude,
                            ),
                            initialLevel: 16,
                          ),
                          if (_mapReady &&
                              _controller != null &&
                              route != null &&
                              route.points.length >= 2)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: RoutePolylineOverlay(
                                  controller: _controller,
                                  points: route.points,
                                  color: _isEstimatedRoute
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF4C9C2A),
                                  borderColor: _isEstimatedRoute
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF2D6A1E),
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
