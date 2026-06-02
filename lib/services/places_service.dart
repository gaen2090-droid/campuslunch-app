import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/campus.dart';
import '../config/env.dart';
import '../utils/business_hours.dart';

class PlaceSearchResult {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final String hours;
  final String hoursDisplay;
  final List<Map<String, dynamic>> hoursPeriods;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    this.hours = BusinessHoursData.defaultHours,
    this.hoursDisplay = '',
    this.hoursPeriods = const [],
  });
}

class PlacesService {
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _key => Env.googleMapsApiKey;

  Future<List<PlaceSearchResult>> search(String query) async {
    if (_key.isEmpty || query.trim().length < 2) return [];

    final q = '${query.trim()} ${Campus.searchBias}';
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
      'query': q,
      'key': _key,
      'language': 'ko',
      'region': 'kr',
    });

    final res = await _client.get(uri);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return [];

    final results = data['results'] as List<dynamic>? ?? [];
    return results.map((raw) {
      final m = raw as Map<String, dynamic>;
      final loc = m['geometry']?['location'] as Map<String, dynamic>? ?? {};
      return PlaceSearchResult(
        placeId: m['place_id'] as String,
        name: m['name'] as String? ?? '',
        address: m['formatted_address'] as String? ?? '',
        latitude: (loc['lat'] as num).toDouble(),
        longitude: (loc['lng'] as num).toDouble(),
      );
    }).toList();
  }

  Future<PlaceDetails?> getDetails(String placeId) async {
    if (_key.isEmpty) return null;

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': _key,
      'language': 'ko',
      'fields': 'place_id,name,formatted_address,geometry,opening_hours,photos',
    });

    final res = await _client.get(uri);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final r = data['result'] as Map<String, dynamic>;
    final loc = r['geometry']?['location'] as Map<String, dynamic>? ?? {};
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

    return PlaceDetails(
      placeId: r['place_id'] as String,
      name: r['name'] as String? ?? '',
      address: r['formatted_address'] as String? ?? '',
      latitude: (loc['lat'] as num).toDouble(),
      longitude: (loc['lng'] as num).toDouble(),
      photoUrl: photoUrl,
      hours: bh.hoursCanonical,
      hoursDisplay: bh.hoursDisplay,
      hoursPeriods: bh.periods,
    );
  }
}
