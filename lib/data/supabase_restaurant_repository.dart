import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  Future<void> reportStatus(String restaurantId, String uiStatus) async {
    final source = uiStatus == '영업안함' ? 'owner' : 'user';
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
    if (data.containsKey('description')) patch['description'] = data['description'];

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
      emoji: extra?['emoji'] as String? ?? seed?.emoji ?? '🍽️',
      imageUrl: row['image_url'] as String? ?? seed?.imageUrl ?? '',
      distance: (extra?['distance'] as num?)?.toDouble() ?? seed?.distance ?? 200,
      x: (extra?['map_x'] as num?)?.toDouble() ?? seed?.x ?? 50,
      y: (extra?['map_y'] as num?)?.toDouble() ?? seed?.y ?? 50,
      hours: extra?['hours'] as String? ?? seed?.hours ?? '11:00 - 21:00',
      reports: reportCounts.isEmpty ? (seed?.reports ?? {}) : reportCounts,
      menu: menu,
    );
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
