// ignore_for_file: avoid_print
/// Mock 매장 데이터 → Supabase 시드 (Secret 키, 앱 미포함)
///
///   cp .env.secrets.example .env.secrets   # URL + Secret
///   dart run tool/seed_restaurants.dart
///   dart run tool/seed_restaurants.dart --reset   # 기존 데이터 삭제 후 재시드
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

import '../lib/data/crowd_level_mapper.dart';

void main(List<String> args) async {
  final reset = args.contains('--reset');
  final secrets = await _loadEnvFile('.env.secrets');
  final fallback = await _loadEnvFile('.env');
  final url = secrets['SUPABASE_URL'] ?? fallback['SUPABASE_URL'] ?? '';
  final secret = secrets['SUPABASE_SECRET_KEY'] ?? '';
  if (url.isEmpty || secret.isEmpty) {
    stderr.writeln('`.env.secrets`에 SUPABASE_URL, SUPABASE_SECRET_KEY를 설정하세요.');
    exit(1);
  }

  final client = SupabaseClient(url, secret);
  final existing = await client.from('restaurants').select('id');

  if (existing.isNotEmpty && !reset) {
    print('이미 ${existing.length}개 매장이 있습니다. 재시드: --reset');
    return;
  }

  if (reset && existing.isNotEmpty) {
    await client.from('crowd_reports').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await client.from('restaurants').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    print('기존 restaurants / crowd_reports 삭제 완료');
  }

  final mocks = _mockRestaurants();
  final rows = mocks.map((m) {
    final copy = Map<String, dynamic>.from(m)..remove('initial_status');
    return copy;
  }).toList();
  final inserted = await client.from('restaurants').insert(rows).select('id,name');

  var reportCount = 0;
  for (var i = 0; i < inserted.length; i++) {
    final row = inserted[i];
    final mock = _mockRestaurants()[i];
    final status = mock['initial_status'] as String;
    await client.from('crowd_reports').insert({
      'restaurant_id': row['id'],
      'level': CrowdLevelMapper.toDb(status),
      'source': 'system',
      'metadata': {'status': status, 'seed': true},
    });
    reportCount++;
  }

  print('시드 완료: 매장 ${inserted.length}개, 혼잡도 제보 $reportCount개');
}

List<Map<String, dynamic>> _mockRestaurants() => [
      _row(
        name: '학식 한식당',
        category: '학식',
        area: '학식',
        address: '학생회관 1층',
        status: '여유로움',
        emoji: '🍚',
        imageUrl:
            'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&q=80&fit=crop',
        distance: 35,
        x: 45,
        y: 39,
        hours: '11:00 - 14:00, 17:00 - 19:00',
        reports: {'여유로움': 12, '약간혼잡': 6, '자리없음': 2},
        menu: [
          {'name': '백반 (밥+국+반찬 4종)', 'price': 4000},
          {'name': '비빔밥', 'price': 4500},
          {'name': '순두부찌개', 'price': 4500},
          {'name': '된장찌개', 'price': 4000},
        ],
        lat: 37.56650,
        lng: 126.97800,
      ),
      _row(
        name: '양셰프',
        category: '양식',
        area: '정문',
        address: '정문 근처',
        status: '약간혼잡',
        emoji: '🍝',
        imageUrl:
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80&fit=crop',
        distance: 340,
        x: 72,
        y: 63,
        hours: '11:30 - 21:00',
        reports: {'여유로움': 4, '약간혼잡': 10, '자리없음': 3},
        menu: [
          {'name': '반반 스테이크', 'price': 7000},
          {'name': '크림 파스타', 'price': 7500},
          {'name': '토마토 파스타', 'price': 7500},
          {'name': '치킨 리조또', 'price': 8000},
          {'name': '오늘의 런치 세트', 'price': 9000},
        ],
        lat: 37.56700,
        lng: 126.97900,
      ),
      _row(
        name: '미들도어',
        category: '카페',
        area: '중문',
        address: '중문 근처',
        status: '여유로움',
        emoji: '☕',
        imageUrl:
            'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600&q=80&fit=crop',
        distance: 43,
        x: 56,
        y: 48,
        hours: '08:00 - 22:00',
        reports: {'여유로움': 8, '약간혼잡': 3, '자리없음': 1},
        menu: [
          {'name': '아메리카노', 'price': 2500},
          {'name': '카페라떼', 'price': 3000},
          {'name': '바닐라라떼', 'price': 3500},
          {'name': '크로플', 'price': 3500},
          {'name': '에그샌드위치', 'price': 4500},
        ],
        lat: 37.56680,
        lng: 126.97850,
      ),
      _row(
        name: '뜸들이다',
        category: '한식',
        area: '후문',
        address: '후문 골목',
        status: '자리없음',
        emoji: '🍲',
        imageUrl:
            'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80&fit=crop',
        distance: 420,
        x: 28,
        y: 66,
        hours: '11:00 - 21:00',
        reports: {'여유로움': 2, '약간혼잡': 5, '자리없음': 11},
        menu: [
          {'name': '뚝배기 불고기', 'price': 8000},
          {'name': '제육볶음 정식', 'price': 7500},
          {'name': '순대국밥', 'price': 7000},
          {'name': '닭갈비 정식', 'price': 8500},
        ],
        lat: 37.56580,
        lng: 126.97700,
      ),
    ];

Map<String, dynamic> _row({
  required String name,
  required String category,
  required String area,
  required String address,
  required String status,
  required String emoji,
  required String imageUrl,
  required double distance,
  required double x,
  required double y,
  required String hours,
  required Map<String, int> reports,
  required List<Map<String, dynamic>> menu,
  required double lat,
  required double lng,
  bool isActive = true,
}) {
  final extra = jsonEncode({
    'emoji': emoji,
    'hours': hours,
    'distance': distance,
    'map_x': x,
    'map_y': y,
    'menu': menu,
    'reports_snapshot': reports,
  });
  return {
    'name': name,
    'category': category,
    'area': area,
    'address': address,
    'image_url': imageUrl,
    'description': extra,
    'latitude': lat,
    'longitude': lng,
    'is_active': isActive,
    'initial_status': status,
  };
}

Future<Map<String, String>> _loadEnvFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return {};
  final map = <String, String>{};
  for (final line in await file.readAsLines()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i <= 0) continue;
    map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
  }
  return map;
}
