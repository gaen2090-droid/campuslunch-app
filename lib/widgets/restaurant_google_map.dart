import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/campus.dart';
import '../config/env.dart';
import '../models/restaurant.dart';
import '../utils/map_marker_hue.dart';
import '../utils/map_marker_icons.dart';

/// DB 식당 마커 + 혼잡도 색상 (기존 지도 UI와 동일 의미)
class RestaurantGoogleMap extends StatefulWidget {
  final List<Restaurant> restaurants;
  final Restaurant? selected;
  final ValueChanged<Restaurant> onSelect;
  final VoidCallback? onDeselect;
  final bool showMyLocation;
  final bool myLocationEnabled;
  final ValueChanged<LatLng>? onMapTap;
  final LatLng? pickMarker;

  const RestaurantGoogleMap({
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
  State<RestaurantGoogleMap> createState() => _RestaurantGoogleMapState();
}

class _RestaurantGoogleMapState extends State<RestaurantGoogleMap> {
  GoogleMapController? _controller;
  static const _campus = LatLng(Campus.centerLat, Campus.centerLng);
  BitmapDescriptor? _closedMarker;
  BitmapDescriptor? _noReportMarker;

  @override
  void initState() {
    super.initState();
    MapMarkerIcons.closed().then((icon) {
      if (mounted) setState(() => _closedMarker = icon);
    });
    MapMarkerIcons.noReport().then((icon) {
      if (mounted) setState(() => _noReportMarker = icon);
    });
  }

  @override
  void didUpdateWidget(RestaurantGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.myLocationEnabled && !oldWidget.myLocationEnabled) {
      _moveToUserLocation();
    }
    if (widget.selected?.id != oldWidget.selected?.id &&
        widget.selected != null) {
      _focusRestaurant(widget.selected!);
    }
  }

  Future<void> _moveToUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16),
      );
    } catch (_) {}
  }

  Future<void> _focusRestaurant(Restaurant r) async {
    if (!r.hasMapLocation) return;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(r.latitude, r.longitude), 17),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final r in widget.restaurants) {
      if (!r.hasMapLocation) continue;
      final isSelected = widget.selected?.id == r.id;
      final noReport = r.status != '영업안함' && !r.hasCrowdUpdate;
      final icon = r.status == '영업안함' && _closedMarker != null
          ? _closedMarker!
          : noReport && _noReportMarker != null
              ? _noReportMarker!
              : BitmapDescriptor.defaultMarkerWithHue(
                  markerHueForStatus(r.status),
                );
      markers.add(
        Marker(
          markerId: MarkerId(r.id),
          position: LatLng(r.latitude, r.longitude),
          icon: icon,
          zIndexInt: isSelected ? 2 : 1,
          infoWindow: InfoWindow(
            title: r.name,
            snippet: noReport ? '제보필요' : r.status,
          ),
          onTap: () => widget.onSelect(r),
        ),
      );
    }

    if (widget.pickMarker != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pick'),
          position: widget.pickMarker!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndexInt: 3,
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.isGoogleMapsConfigured) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'GOOGLE_MAPS_API_KEY가 .env에 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: _campus, zoom: 15.5),
      markers: _buildMarkers(),
      myLocationEnabled: widget.showMyLocation && widget.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (c) => _controller = c,
      onTap: widget.onDeselect != null || widget.onMapTap != null
          ? (pos) {
              widget.onDeselect?.call();
              widget.onMapTap?.call(pos);
            }
          : null,
    );
  }
}
