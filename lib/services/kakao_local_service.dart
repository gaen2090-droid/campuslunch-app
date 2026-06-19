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
  final String? phone;
  final String? categoryName;
  final String? placeUrl;

  const PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.categoryName,
    this.placeUrl,
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
  final String? phone;
  final String? placeUrl;
  final String? googlePlaceId;

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
    this.phone,
    this.placeUrl,
    this.googlePlaceId,
  });

  factory PlaceDetails.fromSearch(PlaceSearchResult item) {
    return PlaceDetails(
      placeId: item.placeId,
      name: item.name,
      address: item.address,
      latitude: item.latitude,
      longitude: item.longitude,
      phone: item.phone,
      placeUrl: item.placeUrl,
    );
  }
}

/// 카카오 로컬 API — 장소 검색 (영업시간·사진은 API 미제공)
class KakaoLocalService {
  KakaoLocalService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> get _headers => {
        'Authorization': 'KakaoAK ${Env.kakaoRestApiKey}',
      };

  Future<List<PlaceSearchResult>> search(String query) async {
    if (query.trim().length < 2) return [];
    if (!Env.isKakaoLocalConfigured) {
      throw StateError('KAKAO_REST_API_KEY가 설정되지 않았어요.');
    }

    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
      'query': '${query.trim()} ${Campus.searchBias}',
      'x': '${Campus.centerLng}',
      'y': '${Campus.centerLat}',
      'radius': '3000',
      'sort': 'distance',
      'size': '15',
    });

    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      final msg = _errorMessage(res);
      throw StateError('장소 검색 실패 (${res.statusCode}): $msg');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = data['documents'] as List<dynamic>? ?? [];
    return docs.map((raw) => _parseDocument(raw as Map<String, dynamic>)).toList();
  }

  PlaceSearchResult _parseDocument(Map<String, dynamic> m) {
    final lng = double.tryParse(m['x'] as String? ?? '') ?? 0;
    final lat = double.tryParse(m['y'] as String? ?? '') ?? 0;
    final road = (m['road_address_name'] as String?)?.trim() ?? '';
    final jibun = (m['address_name'] as String?)?.trim() ?? '';

    return PlaceSearchResult(
      placeId: m['id'] as String? ?? '',
      name: m['place_name'] as String? ?? '',
      address: road.isNotEmpty ? road : jibun,
      latitude: lat,
      longitude: lng,
      phone: (m['phone'] as String?)?.trim(),
      categoryName: m['category_name'] as String?,
      placeUrl: m['place_url'] as String?,
    );
  }

  Future<PlaceDetails?> getDetails(String placeId) async {
    if (placeId.isEmpty) return null;
    if (!Env.isKakaoLocalConfigured) return null;

    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
      'query': placeId,
      'x': '${Campus.centerLng}',
      'y': '${Campus.centerLat}',
      'radius': '20000',
      'size': '15',
    });

    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = data['documents'] as List<dynamic>? ?? [];
    for (final raw in docs) {
      final item = _parseDocument(raw as Map<String, dynamic>);
      if (item.placeId == placeId) {
        return PlaceDetails.fromSearch(item);
      }
    }
    return null;
  }

  String _errorMessage(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['message'] as String?)?.trim() ?? res.body;
    } catch (_) {
      return res.body;
    }
  }
}
