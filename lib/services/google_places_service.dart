import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/campus.dart';
import '../config/env.dart';
import '../utils/business_hours.dart';

/// Google Places로 영업시간·사진 보강 (지도/검색은 카카오)
class GooglePlaceEnrichment {
  final String googlePlaceId;
  final String? photoUrl;
  final String hours;
  final String hoursDisplay;
  final List<Map<String, dynamic>> hoursPeriods;

  const GooglePlaceEnrichment({
    required this.googlePlaceId,
    this.photoUrl,
    this.hours = BusinessHoursData.defaultHours,
    this.hoursDisplay = '',
    this.hoursPeriods = const [],
  });
}

class GooglePlacesService {
  GooglePlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _key => Env.googleMapsApiKey;

  /// 카카오로 고른 매장 좌표·이름 기준 Google Places 매칭 → 영업시간·사진
  Future<GooglePlaceEnrichment?> enrich({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    if (_key.isEmpty) return null;

    final placeId = await _findPlaceId(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    if (placeId == null) return null;

    return _fetchEnrichment(placeId);
  }

  Future<String?> _findPlaceId({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final q = '$name ${address.trim()} ${Campus.searchBias}'.trim();
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
      'query': q,
      'key': _key,
      'language': 'ko',
      'region': 'kr',
      'location': '$latitude,$longitude',
      'radius': '500',
    });

    final res = await _client.get(uri);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final results = data['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return null;

    String? bestId;
    var bestDist = double.infinity;
    for (final raw in results) {
      final m = raw as Map<String, dynamic>;
      final loc = m['geometry']?['location'] as Map<String, dynamic>? ?? {};
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final d = _haversineMeters(latitude, longitude, lat, lng);
      if (d < bestDist) {
        bestDist = d;
        bestId = m['place_id'] as String?;
      }
    }
    return bestId;
  }

  Future<GooglePlaceEnrichment?> _fetchEnrichment(String placeId) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': _key,
      'language': 'ko',
      'fields': 'place_id,opening_hours,photos',
    });

    final res = await _client.get(uri);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final r = data['result'] as Map<String, dynamic>;
    final bh = BusinessHoursData.fromGoogleOpeningHours(
      r['opening_hours'] as Map<String, dynamic>?,
    );

    String? photoUrl;
    final photos = r['photos'] as List<dynamic>?;
    if (photos != null && photos.isNotEmpty) {
      final ref = (photos.first as Map)['photo_reference'] as String?;
      if (ref != null) {
        photoUrl = Uri.https('maps.googleapis.com', '/maps/api/place/photo', {
          'maxwidth': '800',
          'photo_reference': ref,
          'key': _key,
        }).toString();
      }
    }

    return GooglePlaceEnrichment(
      googlePlaceId: r['place_id'] as String? ?? placeId,
      photoUrl: photoUrl,
      hours: bh.hoursCanonical,
      hoursDisplay: bh.hoursDisplay,
      hoursPeriods: bh.periods,
    );
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.asin(math.sqrt(a));
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
}
