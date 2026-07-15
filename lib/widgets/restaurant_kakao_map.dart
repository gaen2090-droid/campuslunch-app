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
import '../utils/marker_overlap.dart';

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
  StreamSubscription? _cameraMoveEndSub;
  bool _mapLayerReady = false;
  String? _mapError;
  final Set<String> _markerIds = {};
  Future<void>? _syncInFlight;
  bool _syncQueued = false;
  int _syncGeneration = 0;
  String _lastFitKey = '';
  int _lastFitToken = -1;

  /// 마커 아이콘 반경(px) — 겹침 판정 기준. 두 마커 중심 간 거리가 이 값의 2배(지름)보다
  /// 가까우면 겹친 것으로 본다. 마커가 실제로 서로 포개질 때만 하나를 숨기도록 작게 잡음
  /// (과도하게 크면 아이콘끼리 안 겹쳐도 숨겨져서 축소 시 마커가 너무 많이 사라짐).
  static const double _markerIconRadiusPixels = 10;
  /// 매장명 라벨 겹침 판정 반경(px). 이 반경 안에 이미 라벨이 표시된 마커가 있으면
  /// 텍스트를 비우고 아이콘만 표시 — "일부 매장명만 뜨는" 카카오맵 라벨 겹침 방지와
  /// 동일한 방식. 마커 판정(_markerIconRadiusPixels)보다만 살짝 크게 잡아, 충분히
  /// 확대해서 마커끼리 떨어지면 라벨도 전부 뜨도록 함(너무 크면 확대해도 라벨이 계속 숨음).
  static const double _labelOverlapRadiusPixels = 20;
  int? _lastZoomLevel;

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
    _cameraMoveEndSub?.cancel();
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
    final selectedChanged = widget.selected?.id != oldWidget.selected?.id &&
        widget.selected != null;
    // 매장 선택으로 인한 카메라 이동이 전체 fit(예: restaurants 리스트 변경)과
    // 동시에 트리거되면 두 카메라 애니메이션이 서로 덮어쓰므로, 선택 포커스를 우선한다.
    if (selectedChanged) {
      unawaited(_focusRestaurant(widget.selected!));
    } else if (_shouldRefitCamera(oldWidget)) {
      unawaited(fitToRestaurants());
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

    _cameraMoveEndSub?.cancel();
    _cameraMoveEndSub = controller.onCameraMoveEndStream.listen((_) {
      unawaited(_onCameraMoveEnd());
    });
  }

  Future<void> _onCameraMoveEnd() async {
    final controller = _controller;
    if (controller == null || !_mapLayerReady) return;
    final zoom = await controller.getZoomLevel();
    if (zoom == null || zoom == _lastZoomLevel) return;
    _lastZoomLevel = zoom;
    unawaited(_syncMarkers());
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
        _mapError = '지도를 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  /// 진행 중인 sync가 있으면 그 완료를 기다렸다가 "최신 상태로" 딱 한 번만 다시 그린다.
  /// (여러 번 연달아 호출돼도 매번 큐잉해서 순차 실행하지 않음 — 낡은 필터 상태가
  /// 화면에 오래 남는 현상 방지)
  Future<void> _syncMarkers() {
    final prev = _syncInFlight;
    if (prev != null) {
      _syncQueued = true;
      return prev;
    }
    final task = _runSyncLoop();
    _syncInFlight = task;
    return task;
  }

  Future<void> _runSyncLoop() async {
    do {
      _syncQueued = false;
      await _syncMarkersImpl();
    } while (_syncQueued);
    _syncInFlight = null;
  }

  Future<void> _syncMarkersImpl() async {
    final controller = _controller;
    if (controller == null || !_mapLayerReady) return;

    final gen = ++_syncGeneration;
    final showMyLocation =
        widget.showMyLocationMarker && widget.myLocationEnabled;
    final sw = Stopwatch()..start();

    try {
      final toRemove = _markerIds.toList(growable: false);
      if (toRemove.isNotEmpty) {
        try {
          await controller.removeMarkers(ids: toRemove);
        } catch (e) {
          debugPrint('[RestaurantKakaoMap] removeMarkers batch failed: $e');
          for (final id in toRemove) {
            await removeMarkerQuietly(controller, id: id);
          }
        }
      }
      debugPrint('[Perf] removeMarkers took ${sw.elapsedMilliseconds}ms (count=${toRemove.length})');
      if (gen != _syncGeneration) return;
      _markerIds.clear();

      final located = widget.restaurants.where((r) => r.hasMapLocation).toList();
      final zoom = await controller.getZoomLevel() ?? _lastZoomLevel ?? 21;
      _lastZoomLevel = zoom;

      final swOverlap = Stopwatch()..start();
      // 겹치는 마커 중 하나만 남김 — 선택된 매장 최우선, 그 다음 혼잡도(여유로움>약간혼잡>그외)
      // 우선, 그 외엔 목록 순서(안정적) 유지.
      final selectedId = widget.selected?.id;
      final candidates = <OverlapCandidate>[];
      for (var i = 0; i < located.length; i++) {
        final r = located[i];
        final statusRank = switch (r.status) {
          '여유로움' => 2,
          '약간혼잡' => 1,
          _ => 0,
        };
        final basePriority = statusRank * located.length + (located.length - i);
        final priority =
            r.id == selectedId ? basePriority + 3 * located.length : basePriority;
        candidates.add(OverlapCandidate(
          id: r.id,
          latitude: r.latitude,
          longitude: r.longitude,
          priority: priority,
        ));
      }
      final visibleIds = MarkerOverlap.resolveVisibleIds(
        candidates: candidates,
        zoomLevel: zoom,
        iconRadiusPixels: _markerIconRadiusPixels,
      ).toSet();

      // 라벨(매장명)은 화면상 서로 겹치지 않는 것만 표시 — 매장 수와 무관하게 항상 동작.
      final visibleCandidates =
          candidates.where((c) => visibleIds.contains(c.id)).toList();
      final labeledIds = MarkerOverlap.resolveVisibleIds(
        candidates: visibleCandidates,
        zoomLevel: zoom,
        iconRadiusPixels: _labelOverlapRadiusPixels,
      ).toSet();
      debugPrint('[Perf] overlap compute took ${swOverlap.elapsedMilliseconds}ms (n=${located.length}, zoom=$zoom, visible=${visibleIds.length})');

      final markerBatch = <MarkerOption>[];
      for (final r in located) {
        if (!visibleIds.contains(r.id)) continue;
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
            text: labeledIds.contains(r.id) ? r.name : null,
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
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
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
          }
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
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
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
      profile: CameraFitProfile.tight,
      animate: true,
      viewportSize: _mapViewportSize(),
      viewportPadding: CameraFitOptions.forProfile(CameraFitProfile.tight).viewportPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.hasKakaoNativeKey) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '지도를 불러올 수 없어요. 잠시 후 다시 시도해주세요.',
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
