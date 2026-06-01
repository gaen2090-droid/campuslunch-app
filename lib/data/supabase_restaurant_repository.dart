import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant.dart';
import '../services/supabase_service.dart';
import 'crowd_level_mapper.dart';
import 'restaurants.dart';

/// Supabase 실제 스키마:
/// - restaurants: uuid id, name, category, area, address, image_url, description, latitude, longitude, ...
/// - crowd_reports: level (enum), source (enum), metadata (jsonb), restaurant_id
class SupabaseRestaurantRepository {
  SupabaseRestaurantRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Restaurant>> fetchAll() async {
    final rows = await _client
        .from('restaurants')
        .select()
        .eq('is_active', true)
        .order('created_at');

    final reports = await _client.from('crowd_reports').select();
    final reportsByRestaurant = _groupReports(reports);

    return rows
        .map((row) => _mergeRow(
              row,
              reportsByRestaurant[row['id'] as String] ?? [],
            ))
        .toList();
  }

  Future<void> reportStatus(String restaurantId, String uiStatus,
      {String source = 'user'}) async {
    await _client.from('crowd_reports').insert({
      'restaurant_id': restaurantId,
      'level': CrowdLevelMapper.toDb(uiStatus),
      'source': source,
      'metadata': {'status': uiStatus},
    });
  }

  Future<Restaurant> insert(Map<String, dynamic> data) async {
    final row = await _client
        .from('restaurants')
        .insert({
          'name': data['name'],
          'category': data['category'],
          'area': data['area'],
          'address': data['address'] ?? data['area'],
          'image_url': data['image_url'] ?? '',
          'description': data['description'] ?? '',
          'latitude': (data['latitude'] as num?)?.toDouble() ?? 0,
          'longitude': (data['longitude'] as num?)?.toDouble() ?? 0,
          'is_active': true,
        })
        .select()
        .single();
    return _mergeRow(row, []);
  }

  Future<Restaurant> update(String id, Map<String, dynamic> data) async {
    final patch = <String, dynamic>{};
    if (data.containsKey('name')) patch['name'] = data['name'];
    if (data.containsKey('category')) patch['category'] = data['category'];
    if (data.containsKey('area')) patch['area'] = data['area'];
    if (data.containsKey('address')) patch['address'] = data['address'];
    if (data.containsKey('image_url')) patch['image_url'] = data['image_url'];

    if (data.containsKey('hours') || data.containsKey('menu')) {
      final existing = await _client
          .from('restaurants')
          .select('description')
          .eq('id', id)
          .single();
      final desc = _parseDescription(existing['description'] as String?) ?? {};
      if (data.containsKey('hours')) desc['hours'] = data['hours'];
      if (data.containsKey('menu')) desc['menu'] = data['menu'];
      patch['description'] = jsonEncode(desc);
    }

    final row = await _client
        .from('restaurants')
        .update(patch)
        .eq('id', id)
        .select()
        .single();

    final reports = await _client
        .from('crowd_reports')
        .select()
        .eq('restaurant_id', id);
    return _mergeRow(row, reports);
  }

  Future<void> delete(String id) async {
    await _client.from('restaurants').update({'is_active': false}).eq('id', id);
  }

  Map<String, List<Map<String, dynamic>>> _groupReports(List<dynamic> rows) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final rid = row['restaurant_id'] as String;
      map.putIfAbsent(rid, () => []).add(row);
    }
    return map;
  }

  Restaurant _mergeRow(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> reports,
  ) {
    final id = row['id'] as String;
    final extra = _parseDescription(row['description'] as String?);
    final seed = extra == null ? _seedByName(row['name'] as String?) : null;

    final sorted = List<Map<String, dynamic>>.from(reports)
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

    final latest = sorted.isNotEmpty ? sorted.first : null;
    final status = latest == null
        ? (seed?.status ?? '여유로움')
        : CrowdLevelMapper.fromDb(
            latest['level'] as String,
            metadata: Map<String, dynamic>.from(
              latest['metadata'] as Map? ?? {},
            ),
          );

    final updated = latest?['created_at'] != null
        ? DateTime.now()
            .difference(DateTime.parse(latest!['created_at'] as String).toLocal())
            .inMinutes
        : 0;

    final snapshot = extra?['reports_snapshot'];
    final reportCounts = <String, int>{};
    if (snapshot is Map) {
      snapshot.forEach((k, v) => reportCounts[k.toString()] = (v as num).toInt());
    } else {
      for (final r in reports) {
        final label = CrowdLevelMapper.fromDb(
          r['level'] as String,
          metadata: Map<String, dynamic>.from(r['metadata'] as Map? ?? {}),
        );
        if (label != '영업안함') {
          reportCounts[label] = (reportCounts[label] ?? 0) + 1;
        }
      }
    }

    final menuList = extra?['menu'];
    final menu = menuList is List
        ? menuList
            .map((m) => MenuItem.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList()
        : (seed?.menu ?? []);

    return Restaurant(
      id: id,
      name: row['name'] as String,
      category: row['category'] as String,
      area: row['area'] as String,
      address: row['address'] as String? ?? row['area'] as String,
      status: status,
      updated: updated,
      imageUrl: row['image_url'] as String? ?? seed?.imageUrl ?? '',
      distance: (extra?['distance'] as num?)?.toDouble() ?? seed?.distance ?? 200,
      x: (extra?['map_x'] as num?)?.toDouble() ?? seed?.x ?? 50,
      y: (extra?['map_y'] as num?)?.toDouble() ?? seed?.y ?? 50,
      hours: extra?['hours'] as String? ?? seed?.hours ?? '11:00 - 21:00',
      reports: reportCounts.isEmpty ? (seed?.reports ?? {}) : reportCounts,
      menu: menu,
      popularityScore: _calcPopularityScore(
        reports,
        extra?['hours'] as String? ?? seed?.hours ?? '',
      ),
      manualRank: (extra?['manual_rank'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> updateManualRanks(Map<String, int> rankById) async {
    for (final entry in rankById.entries) {
      final existing = await _client
          .from('restaurants')
          .select('description')
          .eq('id', entry.key)
          .single();
      final desc = _parseDescription(existing['description'] as String?) ?? {};
      desc['manual_rank'] = entry.value;
      await _client
          .from('restaurants')
          .update({'description': jsonEncode(desc)})
          .eq('id', entry.key);
    }
  }

  // ── 인기도 점수 계산 ──
  // (약간혼잡 지속 토큰*1 + 자리없음 지속 토큰*2), 토큰=5분, 영업시간 내만 집계, 최근 7일
  int _calcPopularityScore(List<Map<String, dynamic>> reports, String hours) {
    final ranges = _parseHoursRanges(hours);
    if (ranges.isEmpty || reports.isEmpty) return 0;

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recent = reports
        .map((r) => {
              ...r,
              '_dt': DateTime.parse(r['created_at'] as String).toLocal(),
            })
        .where((r) => (r['_dt'] as DateTime).isAfter(weekAgo))
        .toList()
      ..sort((a, b) =>
          (a['_dt'] as DateTime).compareTo(b['_dt'] as DateTime));

    if (recent.isEmpty) return 0;

    int score = 0;
    for (int i = 0; i < recent.length; i++) {
      final status = CrowdLevelMapper.fromDb(
        recent[i]['level'] as String,
        metadata: Map<String, dynamic>.from(recent[i]['metadata'] as Map? ?? {}),
      );
      final weight = status == '약간혼잡' ? 1 : (status == '자리없음' ? 2 : 0);
      if (weight == 0) continue;

      final start = recent[i]['_dt'] as DateTime;
      final DateTime end;
      if (i + 1 < recent.length) {
        end = recent[i + 1]['_dt'] as DateTime;
      } else {
        // 마지막 제보: 해당 영업 구간 끝까지 연장
        final sm = start.hour * 60 + start.minute;
        final range = ranges.firstWhere(
          (r) => sm >= r.$1 && sm < r.$2,
          orElse: () => (0, 0),
        );
        if (range.$2 == 0) continue;
        end = DateTime(start.year, start.month, start.day,
            range.$2 ~/ 60, range.$2 % 60);
      }

      final mins = _minsWithinHours(start, end, ranges);
      score += (mins ~/ 5) * weight;
    }
    return score;
  }

  // "11:00 - 14:00, 17:00 - 19:00" → [(660,840),(1020,1140)]
  List<(int, int)> _parseHoursRanges(String hours) {
    final ranges = <(int, int)>[];
    for (final part in hours.split(',')) {
      final m = RegExp(r'(\d{1,2}):(\d{2})\s*[-~]\s*(\d{1,2}):(\d{2})')
          .firstMatch(part.trim());
      if (m != null) {
        final s = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
        final e = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
        if (e > s) ranges.add((s, e));
      }
    }
    return ranges;
  }

  // [start, end] 중 영업시간과 겹치는 분(minute) 수 계산
  int _minsWithinHours(DateTime start, DateTime end, List<(int, int)> ranges) {
    if (!start.isBefore(end)) return 0;
    int total = 0;
    var day = DateTime(start.year, start.month, start.day);
    final lastDay = DateTime(end.year, end.month, end.day);
    while (!day.isAfter(lastDay)) {
      final wStart = day.year == start.year && day.month == start.month && day.day == start.day
          ? start.hour * 60 + start.minute
          : 0;
      final wEnd = day.year == end.year && day.month == end.month && day.day == end.day
          ? end.hour * 60 + end.minute
          : 24 * 60;
      for (final r in ranges) {
        final oStart = wStart > r.$1 ? wStart : r.$1;
        final oEnd = wEnd < r.$2 ? wEnd : r.$2;
        if (oEnd > oStart) total += oEnd - oStart;
      }
      day = day.add(const Duration(days: 1));
    }
    return total;
  }

  Map<String, dynamic>? _parseDescription(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Restaurant? _seedByName(String? name) {
    if (name == null) return null;
    for (final r in initialRestaurants) {
      if (r.name == name) return r;
    }
    return null;
  }
}
