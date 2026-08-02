import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/env.dart';
import '../models/map_lat_lng.dart';
import '../models/restaurant.dart';
import '../models/route_summary.dart';
import '../services/kakao_map_bootstrap.dart';
import '../services/osrm_directions_service.dart';
import '../utils/kakao_map_ready.dart';
import '../utils/kakao_route_line.dart';
import '../utils/map_camera_fit.dart';

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
  bool _waitingKakaoMapSdk = false;

  MapLatLng get _destination => MapLatLng(
        widget.restaurant.latitude,
        widget.restaurant.longitude,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_loadRoute());
    _ensureKakaoMapSdk();
  }

  void _ensureKakaoMapSdk() {
    if (Env.kakaoMapSdkInitialized || !Env.hasKakaoNativeKey) return;
    _waitingKakaoMapSdk = true;
    unawaited(
      KakaoMapBootstrap.ensureInitialized().then((_) {
        if (!mounted) return;
        setState(() => _waitingKakaoMapSdk = false);
      }),
    );
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
    String? locationError;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationError = '위치 권한이 꺼져 있어요.\n휴대폰 설정에서 위치 권한을 허용해주세요.';
      } else if (!await Geolocator.isLocationServiceEnabled()) {
        locationError = '기기의 위치 서비스가 꺼져 있어요.\n휴대폰 설정에서 위치(GPS)를 켜주세요.';
      } else {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null &&
            DateTime.now().difference(lastKnown.timestamp).inMinutes < 5) {
          origin = MapLatLng(lastKnown.latitude, lastKnown.longitude);
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
          origin = MapLatLng(pos.latitude, pos.longitude);
        }
      }
    } on LocationServiceDisabledException {
      locationError = '기기의 위치 서비스가 꺼져 있어요.\n휴대폰 설정에서 위치(GPS)를 켜주세요.';
    } on TimeoutException {
      debugPrint('[Directions] location fix timed out');
      locationError = '현재 위치를 확인할 수 없어요.\n신호가 약한 곳이라면 실외에서 다시 시도해주세요.';
    } catch (e, st) {
      debugPrint('[Directions] location failed: $e\n$st');
      locationError = '현재 위치를 확인할 수 없어요.\n위치 권한을 켜고 다시 시도해주세요.';
    }

    if (origin == null) {
      setState(() {
        _loadingRoute = false;
        _error = locationError ?? '현재 위치를 확인할 수 없어요.\n위치 권한을 켜고 다시 시도해주세요.';
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
    // runWhenKakaoMapReady가 타임아웃으로 조용히 리턴하면 _mapReady가
    // 계속 false로 남아 로딩 오버레이가 영구히 떠 있게 되므로 강제 해제.
    if (mounted && !_mapReady) {
      setState(() => _mapReady = true);
      unawaited(_setupMap());
    }
  }

  Future<void> _setupMap() async {
    final controller = _controller;
    final origin = _origin;
    final route = _route;
    if (controller == null || origin == null || route == null) return;

    try {
      await runWhenKakaoMapReady(controller, () async {
        await KakaoRouteLine.clear(controller);
        await removeMarkerQuietly(controller, id: 'route_origin');
        await removeMarkerQuietly(controller, id: 'route_destination');

        final lineColor = _isEstimatedRoute
            ? KakaoRouteLineStyle.estimatedColor
            : KakaoRouteLineStyle.color;
        final borderColor = _isEstimatedRoute
            ? KakaoRouteLineStyle.estimatedBorderColor
            : KakaoRouteLineStyle.borderColor;
        final lineWidth = _isEstimatedRoute
            ? KakaoRouteLineStyle.estimatedWidth
            : KakaoRouteLineStyle.width;

        final routeForDraw = simplifyRoutePoints(route.points);
        final drawn = await KakaoRouteLine.set(
          controller,
          points: routeForDraw,
          color: lineColor,
          borderColor: borderColor,
          width: lineWidth,
        );
        if (!drawn) {
          debugPrint('[Directions] native route polyline failed');
        }

        final originStyle =
            KakaoMarkerLayer.styleIdOrNull(controller, 'pin_my_location');
        final destStyle =
            KakaoMarkerLayer.styleIdOrNull(controller, 'pin_destination');

        await controller.addMarker(
          markerOption: MarkerOption(
            id: 'route_origin',
            latLng:
                LatLng(latitude: origin.latitude, longitude: origin.longitude),
            styleId: originStyle,
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
            styleId: destStyle,
            rank: 2,
            text: widget.restaurant.name,
          ),
        );

        if (!mounted) return;
        final screen = MediaQuery.sizeOf(context);
        await MapCameraFit.moveToFit(
          controller,
          [
            origin,
            _destination,
            ...boundsSampleFromRoute(route.points),
          ],
          profile: CameraFitProfile.balanced,
          viewportSize: Size(screen.width, screen.height - 120),
        );
      });
    } catch (e, st) {
      debugPrint('[Directions] setupMap failed: $e\n$st');
    }
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
        titleSpacing: 0,
        title: Text(
          r.name,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          if (route != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              color: const Color(0xFFF0F4FA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_walk,
                          size: 18, color: Color(0xFF3566B8)),
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
                          color: Color(0xFF4A7FE5),
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
                          else if (_waitingKakaoMapSdk)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4A7FE5),
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
                          if (Env.isKakaoMapConfigured &&
                              (_loadingRoute || !_mapReady))
                            const ColoredBox(
                              color: Color(0x66FFFFFF),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4A7FE5),
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
