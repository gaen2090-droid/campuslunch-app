import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/campus.dart';
import '../config/env.dart';
import '../models/restaurant.dart';
import '../services/kakao_map_bootstrap.dart';
import '../utils/kakao_map_ready.dart';
import '../utils/map_camera_fit.dart';
import '../utils/map_marker_icons.dart';

/// DB 매장 마커 + 혼잡도 색상 (카카오맵 SDK)
class RestaurantKakaoMap extends StatefulWidget {
  final List<Restaurant> restaurants;
  final Restaurant? selected;
  final ValueChanged<Restaurant> onSelect;
  final VoidCallback? onDeselect;
  final bool showMyLocationMarker;
  final bool myLocationEnabled;
  final int cameraFitToken;
  final CameraFitProfile cameraFitProfile;
  final ValueChanged<MapLatLngCallback>? onMapTap;
  final ({double lat, double lng})? pickMarker;
  final void Function(RestaurantKakaoMapState map)? onMapReady;

  /// 최초 진입 시에만 적용되는 카메라 포커스 (필터와 무관하게 정문 일대 우선 노출용)
  final List<Restaurant>? initialFocusRestaurants;
  final CameraFitProfile initialFocusProfile;

  const RestaurantKakaoMap({
    super.key,
    required this.restaurants,
    required this.selected,
    required this.onSelect,
    this.onDeselect,
    this.showMyLocationMarker = true,
    this.myLocationEnabled = false,
    this.cameraFitToken = 0,
    this.cameraFitProfile = CameraFitProfile.balanced,
    this.onMapTap,
    this.pickMarker,
    this.onMapReady,
    this.initialFocusRestaurants,
    this.initialFocusProfile = CameraFitProfile.tight,
  });

  @override
  State<RestaurantKakaoMap> createState() => RestaurantKakaoMapState();
}

typedef MapLatLngCallback = ({double latitude, double longitude});

class RestaurantKakaoMapState extends State<RestaurantKakaoMap>
    with WidgetsBindingObserver {
  KakaoMapController? _controller;
  StreamSubscription? _labelSub;
  bool _mapLayerReady = false;
  String? _mapError;
  final Set<String> _markerIds = {};
  Future<void>? _syncInFlight;
  int _syncGeneration = 0;
  String _lastFitKey = '';
  int _lastFitToken = -1;

  static final _campus = LatLng(
    latitude: Campus.centerLat,
    longitude: Campus.centerLng,
  );

  void refreshAfterReturn() {
    if (_controller == null || !_mapLayerReady) return;
    _attachLabelListener();
    unawaited(_syncMarkers());
  }

  Future<void> moveToMyLocation() => _moveToUserLocation();

  String _fitKeyFor(List<Restaurant> restaurants) {
    final located = restaurants.where((r) => r.hasMapLocation).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return located
        .map(
          (r) =>
              '${r.id}:${r.latitude.toStringAsFixed(6)}:${r.longitude.toStringAsFixed(6)}',
        )
        .join('|');
  }

  bool _shouldRefitCamera(RestaurantKakaoMap oldWidget) {
    if (widget.cameraFitToken != oldWidget.cameraFitToken) return true;
    if (widget.cameraFitProfile != oldWidget.cameraFitProfile) return true;
    return _fitKeyFor(widget.restaurants) != _fitKeyFor(oldWidget.restaurants);
  }

  Size _mapViewportSize() {
    final mq = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top + 150;
    final bottom = widget.selected != null ? 260.0 : 72.0;
    return Size(mq.width, math.max(200, mq.height - top - bottom));
  }

  EdgeInsets _mapViewportPadding() =>
      CameraFitOptions.forProfile(widget.cameraFitProfile).viewportPadding;

  bool _didInitialFocusFit = false;

  Future<void> fitToRestaurants({bool animate = true}) async {
    final controller = _controller;
    if (controller == null || !_mapLayerReady) return;

    final useInitialFocus =
        !_didInitialFocusFit && (widget.initialFocusRestaurants?.isNotEmpty ?? false);
    final source = useInitialFocus ? widget.initialFocusRestaurants! : widget.restaurants;
    final profile = useInitialFocus ? widget.initialFocusProfile : widget.cameraFitProfile;

    final points = source
        .where(
          (r) => r.hasMapLocation && Campus.containsLatLng(r.latitude, r.longitude),
        )
        .map((r) => LatLng(latitude: r.latitude, longitude: r.longitude))
        .toList();

    if (points.isEmpty) return;

    _didInitialFocusFit = true;
    _lastFitKey = _fitKeyFor(widget.restaurants);
    _lastFitToken = widget.cameraFitToken;

    await MapCameraFit.moveToFitLatLngs(
      controller,
      points,
      profile: profile,
      animate: animate,
      viewportSize: _mapViewportSize(),
      viewportPadding: _mapViewportPadding(),
    );
  }

  bool _waitingKakaoMapSdk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _labelSub?.cancel();
    final viewId = _controller?.viewId;
    if (viewId != null) {
      KakaoMarkerLayer.release(viewId);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshAfterReturn();
    }
  }

  @override
  void didUpdateWidget(RestaurantKakaoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_mapLayerReady) return;

    if (widget.myLocationEnabled != oldWidget.myLocationEnabled ||
        widget.showMyLocationMarker != oldWidget.showMyLocationMarker) {
      unawaited(_syncMarkers());
    }
    if (_shouldRefitCamera(oldWidget)) {
      unawaited(fitToRestaurants());
    }
    if (widget.selected?.id != oldWidget.selected?.id &&
        widget.selected != null) {
      _focusRestaurant(widget.selected!);
    }
    if (widget.restaurants != oldWidget.restaurants ||
        widget.selected?.id != oldWidget.selected?.id ||
        widget.pickMarker != oldWidget.pickMarker) {
      unawaited(_syncMarkers());
    }
  }

  void _attachLabelListener() {
    final controller = _controller;
    if (controller == null) return;

    _labelSub?.cancel();
    _labelSub = controller.onLabelClickedStream.listen((event) {
      final id = event.labelId;
      if (id == 'pick' || id == 'my_location') return;
      for (final r in widget.restaurants) {
        if (r.id == id) {
          widget.onSelect(r);
          return;
        }
      }
    });
  }

  Future<void> _onMapCreated(KakaoMapController controller) async {
    _controller = controller;

    try {
      await runWhenKakaoMapReady(controller, () async {
        await ensureKakaoMarkerLayer(controller);
        if (!mounted) return;
        _mapLayerReady = true;

        _attachLabelListener();
        final fitKey = _fitKeyFor(widget.restaurants);
        if (fitKey.isNotEmpty &&
            (fitKey != _lastFitKey || widget.cameraFitToken != _lastFitToken)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(fitToRestaurants(animate: false));
          });
        }
        await _syncMarkers();
        if (!mounted) return;
        widget.onMapReady?.call(this);
      });
    } catch (e, st) {
      debugPrint('[RestaurantKakaoMap] onMapCreated failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _mapError = '지도 로드 실패(디버그):\n$e';
      });
    }
  }

  Future<void> _syncMarkers() {
    final prev = _syncInFlight;
    if (prev != null) {
      return prev.then((_) => _syncMarkers());
    }
    final task = _syncMarkersImpl();
    _syncInFlight = task;
    return task.whenComplete(() {
      if (identical(_syncInFlight, task)) _syncInFlight = null;
    });
  }

  Future<void> _syncMarkersImpl() async {
    final controller = _controller;
    if (controller == null || !_mapLayerReady) return;

    final gen = ++_syncGeneration;
    final showMyLocation =
        widget.showMyLocationMarker && widget.myLocationEnabled;

    try {
      final toRemove = _markerIds.toList(growable: false);
      for (final id in toRemove) {
        await removeMarkerQuietly(controller, id: id);
      }
      if (gen != _syncGeneration) return;
      _markerIds.clear();

      final markerBatch = <MarkerOption>[];
      for (final r in widget.restaurants) {
        if (!r.hasMapLocation) continue;
        if (gen != _syncGeneration) return;

        final isSelected = widget.selected?.id == r.id;
        final noReport = r.status != '영업안함' && !r.hasCrowdUpdate;
        final desiredStyleId = r.status == '영업안함'
            ? MapMarkerIcons.styleIdForStatus('영업안함')
            : noReport
                ? 'pin_no_report'
                : MapMarkerIcons.styleIdForStatus(r.status);
        final styleId =
            KakaoMarkerLayer.styleIdOrNull(controller, desiredStyleId);

        markerBatch.add(
          MarkerOption(
            id: r.id,
            latLng: LatLng(latitude: r.latitude, longitude: r.longitude),
            styleId: styleId,
            rank: isSelected ? 2 : 1,
            text: r.name,
          ),
        );
        _markerIds.add(r.id);
      }

      for (var i = 0; i < markerBatch.length; i += 25) {
        if (gen != _syncGeneration) return;
        final chunk = markerBatch.sublist(
          i,
          math.min(i + 25, markerBatch.length),
        );
        try {
          await controller.addMarkers(markerOptions: chunk);
        } catch (e, st) {
          debugPrint('[RestaurantKakaoMap] addMarkers batch failed: $e\n$st');
          for (final option in chunk) {
            if (gen != _syncGeneration) return;
            try {
              await controller.addMarker(markerOption: option);
            } catch (e2) {
              debugPrint(
                '[RestaurantKakaoMap] marker ${option.id} skipped: $e2',
              );
              _markerIds.remove(option.id);
            }
          }
        }
      }

      if (showMyLocation) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );
          if (gen != _syncGeneration) return;
          final myStyleId = KakaoMarkerLayer.styleIdOrNull(
            controller,
            'pin_my_location',
          );
          await controller.addMarker(
            markerOption: MarkerOption(
              id: 'my_location',
              latLng: LatLng(
                latitude: pos.latitude,
                longitude: pos.longitude,
              ),
              styleId: myStyleId,
              rank: 3,
              text: '내 위치',
            ),
          );
          _markerIds.add('my_location');
        } catch (e) {
          debugPrint('[RestaurantKakaoMap] my location marker failed: $e');
        }
      }

      final pick = widget.pickMarker;
      if (pick != null && gen == _syncGeneration) {
        final pickStyleId =
            KakaoMarkerLayer.styleIdOrNull(controller, 'pin_no_report');
        await controller.addMarker(
          markerOption: MarkerOption(
            id: 'pick',
            latLng: LatLng(latitude: pick.lat, longitude: pick.lng),
            styleId: pickStyleId,
            rank: 3,
          ),
        );
        _markerIds.add('pick');
      }
    } catch (e, st) {
      debugPrint('[RestaurantKakaoMap] marker sync failed: $e\n$st');
    }
  }

  Future<void> _moveToUserLocation() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await MapCameraFit.moveToFitLatLngs(
        controller,
        [LatLng(latitude: pos.latitude, longitude: pos.longitude)],
        animate: true,
      );
    } catch (_) {}
  }

  Future<void> _focusRestaurant(Restaurant r) async {
    final controller = _controller;
    if (!r.hasMapLocation || controller == null) return;
    await MapCameraFit.moveToFitLatLngs(
      controller,
      [LatLng(latitude: r.latitude, longitude: r.longitude)],
      animate: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.hasKakaoNativeKey) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'KAKAO_NATIVE_APP_KEY가 설정되지 않았어요.\n'
            'dart run tool/sync_env_to_native.dart 후 다시 빌드해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    if (!Env.kakaoMapSdkInitialized) {
      if (_waitingKakaoMapSdk || !KakaoMapBootstrap.initFailed) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF5E8C4A),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '지도를 준비하고 있어요…',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '카카오맵 SDK 초기화에 실패했어요.\n앱을 다시 실행해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    if (_mapError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _mapError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return KakaoMap(
      onMapCreated: _onMapCreated,
      initialPosition: _campus,
      initialLevel: 15,
      logo: const Logo(alignment: LogoAlignment.bottomLeft),
    );
  }
}
