import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/campus.dart';
import '../config/env.dart';
import '../models/restaurant.dart';
import '../utils/map_marker_icons.dart';

import '../utils/kakao_map_ready.dart';

/// DB 식당 마커 + 혼잡도 색상 (카카오맵 SDK)
class RestaurantKakaoMap extends StatefulWidget {
  final List<Restaurant> restaurants;
  final Restaurant? selected;
  final ValueChanged<Restaurant> onSelect;
  final VoidCallback? onDeselect;
  final bool showMyLocation;
  final bool myLocationEnabled;
  final ValueChanged<MapLatLngCallback>? onMapTap;
  final ({double lat, double lng})? pickMarker;

  const RestaurantKakaoMap({
    super.key,
    required this.restaurants,
    required this.selected,
    required this.onSelect,
    this.onDeselect,
    this.showMyLocation = true,
    this.myLocationEnabled = false,
    this.onMapTap,
    this.pickMarker,
  });

  @override
  State<RestaurantKakaoMap> createState() => _RestaurantKakaoMapState();
}

typedef MapLatLngCallback = ({double latitude, double longitude});

class _RestaurantKakaoMapState extends State<RestaurantKakaoMap> {
  KakaoMapController? _controller;
  StreamSubscription? _labelSub;
  bool _stylesReady = false;
  final Set<String> _markerIds = {};

  static final _campus = LatLng(
    latitude: Campus.centerLat,
    longitude: Campus.centerLng,
  );

  @override
  void dispose() {
    _labelSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(RestaurantKakaoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _stylesReady) {
      if (widget.myLocationEnabled != oldWidget.myLocationEnabled) {
        unawaited(_syncMarkers());
        if (widget.myLocationEnabled) {
          _moveToUserLocation();
        }
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
  }

  Future<void> _onMapCreated(KakaoMapController controller) async {
    _controller = controller;

    await runWhenKakaoMapReady(controller, () async {
      await ensureKakaoMarkerLayer(controller);
      _stylesReady = true;

      _labelSub?.cancel();
      _labelSub = controller.onLabelClickedStream.listen((event) {
        final id = event.labelId;
        if (id == 'pick') return;
        for (final r in widget.restaurants) {
          if (r.id == id) {
            widget.onSelect(r);
            return;
          }
        }
      });

      await _syncMarkers();
    });
  }

  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null || !_stylesReady) return;

    try {
      for (final id in _markerIds) {
        await controller.removeMarker(id: id);
      }
      _markerIds.clear();

      for (final r in widget.restaurants) {
        if (!r.hasMapLocation) continue;
        final isSelected = widget.selected?.id == r.id;
        final noReport = r.status != '영업안함' && !r.hasCrowdUpdate;
        final desiredStyleId = r.status == '영업안함'
            ? MapMarkerIcons.styleIdForStatus('영업안함')
            : noReport
                ? 'pin_no_report'
                : MapMarkerIcons.styleIdForStatus(r.status);

        await controller.addMarker(
          markerOption: MarkerOption(
            id: r.id,
            latLng: LatLng(latitude: r.latitude, longitude: r.longitude),
            styleId: KakaoMarkerLayer.styleIdOrNull(desiredStyleId),
            rank: isSelected ? 2 : 1,
            text: r.name,
          ),
        );
        _markerIds.add(r.id);
      }

      if (widget.myLocationEnabled) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );
          await controller.addMarker(
            markerOption: MarkerOption(
              id: 'my_location',
              latLng: LatLng(
                latitude: pos.latitude,
                longitude: pos.longitude,
              ),
              styleId: KakaoMarkerLayer.styleIdOrNull('pin_my_location'),
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
      if (pick != null) {
        await controller.addMarker(
          markerOption: MarkerOption(
            id: 'pick',
            latLng: LatLng(latitude: pick.lat, longitude: pick.lng),
            styleId: KakaoMarkerLayer.styleIdOrNull('pin_no_report'),
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
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await _controller?.moveCamera(
        cameraUpdate: CameraUpdate.fromLatLng(
          LatLng(latitude: pos.latitude, longitude: pos.longitude),
        ),
        animation: const CameraAnimation(
          duration: 400,
          autoElevation: true,
          isConsecutive: false,
        ),
      );
    } catch (_) {}
  }

  Future<void> _focusRestaurant(Restaurant r) async {
    if (!r.hasMapLocation) return;
    await _controller?.moveCamera(
      cameraUpdate: CameraUpdate.fromLatLng(
        LatLng(latitude: r.latitude, longitude: r.longitude),
      ),
      animation: const CameraAnimation(
        duration: 400,
        autoElevation: true,
        isConsecutive: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.isKakaoMapConfigured) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'KAKAO_NATIVE_APP_KEY가 .env에 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
