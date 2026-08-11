import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/crowd_report.dart';
import '../models/dashboard_metrics.dart';
import '../models/owner_seat_update.dart';
import '../models/restaurant.dart';
import '../models/reward.dart';
import '../services/supabase_service.dart';
import '../utils/business_hours.dart';
import 'crowd_level_mapper.dart';
import 'crowd_status_helpers.dart';

/// Supabase 실제 스키마:
/// - restaurants: uuid id, name, category, area, address, image_url, description, latitude, longitude, ...
/// - crowd_reports: level (crowd_level enum), source (crowd_source enum), metadata (jsonb)
class SupabaseRestaurantRepository {
  SupabaseRestaurantRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Restaurant>> fetchAll({bool includeInactive = false}) async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 1)).toUtc().toIso8601String();

    var query = _client.from('restaurants').select();
    final rows = includeInactive
        ? await query.order('created_at')
        : await query.eq('is_active', true).order('created_at');

    // 오늘 영업 시작 이후 제보만 가져옴 (자정 기준으로 충분히 커버)
    final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final reports = await _client
        .from('crowd_reports')
        .select()
        .gte('created_at', todayStart);
    final reportsByRestaurant = _groupReports(reports);
    final crowdStatusByRestaurant = await _fetchCrowdStatusMap();

    // 1시간 이내 사장님 업데이트만 가져와서 매장별 최신 시각 매핑
    final ownerRows = await _client
        .from('owner_seat_updates')
        .select('restaurant_id, created_at')
        .gte('created_at', cutoff)
        .order('created_at', ascending: false);
    final ownerUpdatedAt = <String, DateTime>{};
    for (final raw in ownerRows) {
      final rid = raw['restaurant_id'] as String;
      if (!ownerUpdatedAt.containsKey(rid)) {
        ownerUpdatedAt[rid] =
            DateTime.parse(raw['created_at'] as String).toLocal();
      }
    }

    return rows.map((row) {
      final id = row['id'] as String;
      final allReports = reportsByRestaurant[id] ?? [];
      final extra = _parseDescription(row['description']);
      final bh = BusinessHoursData.fromDescription(extra);
      final isOpen = bh.isOpenAt(now);

      if (isOpen) {
        final userReports = allReports
            .where((r) => (r['source'] as String?) != 'system')
            .toList();
        return _mergeRow(
          row,
          userReports,
          crowdStatus: crowdStatusByRestaurant[id],
          now: now,
          ownerUpdatedAt: ownerUpdatedAt[id],
          isOpen: true,
        );
      }
      return _mergeRow(
        row,
        allReports,
        crowdStatus: crowdStatusByRestaurant[id],
        now: now,
        ownerUpdatedAt: ownerUpdatedAt[id],
        isOpen: false,
      ).copyWith(status: '영업안함', updated: 0, hasCrowdUpdate: false);
    }).toList();
  }

  /// App Link 번호(/r/{linkNo})로 매장 1건 조회
  Future<Restaurant?> fetchByLinkNo(int linkNo) async {
    if (linkNo <= 0) return null;
    try {
      final rows = await _client
          .from('restaurants')
          .select()
          .eq('link_no', linkNo)
          .eq('is_active', true)
          .limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      final id = row['id'] as String;
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final reports = await _client
          .from('crowd_reports')
          .select()
          .eq('restaurant_id', id)
          .gte('created_at', todayStart);
      final crowdMap = await _fetchCrowdStatusMap();
      final extra = _parseDescription(row['description']);
      final bh = BusinessHoursData.fromDescription(extra);
      final isOpen = bh.isOpenAt(now);
      final userReports = List<Map<String, dynamic>>.from(reports)
          .where((r) => (r['source'] as String?) != 'system')
          .toList();
      if (isOpen) {
        return _mergeRow(
          row,
          userReports,
          crowdStatus: crowdMap[id],
          now: now,
          isOpen: true,
        );
      }
      return _mergeRow(
        row,
        List<Map<String, dynamic>>.from(reports),
        crowdStatus: crowdMap[id],
        now: now,
        isOpen: false,
      ).copyWith(status: '영업안함', updated: 0, hasCrowdUpdate: false);
    } catch (e, st) {
      debugPrint('[Supabase] fetchByLinkNo failed: $e\n$st');
      return null;
    }
  }

  /// 사장님 통계용: 본인 매장의 누적 즐겨찾기 수
  Future<int> fetchOwnerRestaurantBookmarkCount(String restaurantId) async {
    try {
      final raw = await _client.rpc(
        'owner_restaurant_bookmark_count',
        params: {'p_restaurant_id': restaurantId},
      );
      if (raw is num) return raw.toInt();
    } catch (e, st) {
      debugPrint('[Supabase] fetchOwnerRestaurantBookmarkCount failed: $e\n$st');
    }
    return 0;
  }

  /// 사장님 통계용: 본인 매장의 오늘/누적 지도 클릭 수 + 오늘 제보수 + 누적 검색수 + 오늘/누적 상세페이지 방문수
  Future<Map<String, int>> fetchOwnerRestaurantEngagementStats(
      String restaurantId) async {
    try {
      final rows = await _client.rpc(
        'owner_restaurant_engagement_stats',
        params: {'p_restaurant_id': restaurantId},
      );
      if (rows is List && rows.isNotEmpty) {
        final row = rows.first as Map;
        return {
          'todayMapClicks': (row['today_map_clicks'] as num?)?.toInt() ?? 0,
          'totalMapClicks': (row['total_map_clicks'] as num?)?.toInt() ?? 0,
          'todayReports': (row['today_reports'] as num?)?.toInt() ?? 0,
          'totalSearchClicks': (row['total_search_clicks'] as num?)?.toInt() ?? 0,
          'todayDetailViews': (row['today_detail_views'] as num?)?.toInt() ?? 0,
          'totalDetailViews': (row['total_detail_views'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e, st) {
      debugPrint('[Supabase] fetchOwnerRestaurantEngagementStats failed: $e\n$st');
    }
    return {
      'todayMapClicks': 0,
      'totalMapClicks': 0,
      'todayReports': 0,
      'totalSearchClicks': 0,
      'todayDetailViews': 0,
      'totalDetailViews': 0,
    };
  }

  /// 사장님 통계용: 이 매장에 대해 사장님으로 승인받은 시점 (매장 자체 등록일이 아님)
  Future<DateTime?> fetchOwnerVerifiedSince(String restaurantId) async {
    try {
      final raw = await _client.rpc(
        'owner_verified_since',
        params: {'p_restaurant_id': restaurantId},
      );
      if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    } catch (e, st) {
      debugPrint('[Supabase] fetchOwnerVerifiedSince failed: $e\n$st');
    }
    return null;
  }

  Future<int> fetchOwnerInfluence() async {
    try {
      final raw = await _client.rpc('get_owner_influence');
      if (raw is num) return raw.toInt().clamp(0, 100);
    } catch (_) {
      try {
        final row = await _client
            .from('system_settings')
            .select('value')
            .eq('key', 'owner_influence')
            .maybeSingle();
        final value = int.tryParse(row?['value']?.toString() ?? '');
        if (value != null) return value.clamp(0, 100);
      } catch (_) {}
    }
    return 80;
  }

  Future<void> setOwnerInfluence(int value) async {
    await _client.rpc('set_owner_influence', params: {'p_value': value});
  }

  Future<Map<String, Map<String, dynamic>>> _fetchCrowdStatusMap() async {
    try {
      final rows = await _client.from('crowd_status').select();
      final map = <String, Map<String, dynamic>>{};
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        map[row['restaurant_id'] as String] = row;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// submit_crowd_report RPC를 호출하고 스탬프 결과를 반환.
  /// RPC가 없거나 void를 반환하는 구버전이면 StampResult.none 반환.
  Future<StampResult> reportStatusWithStamp(
    String restaurantId,
    String uiStatus, {
    String source = 'user',
    String? userId,
    String? nickname,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final raw = await _client.rpc('submit_crowd_report', params: {
        'p_restaurant_id': restaurantId,
        'p_status': uiStatus,
        'p_source': source,
        'p_lat': latitude,
        'p_lng': longitude,
      });
      if (raw is Map) {
        return StampResult.fromJson(Map<String, dynamic>.from(raw));
      }
      return StampResult.none;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' ||
          e.message.contains('submit_crowd_report') ||
          e.message.contains('Could not find')) {
        debugPrint('[Supabase] submit_crowd_report RPC missing, fallback insert');
      } else {
        rethrow;
      }
    }
    // 폴백: 직접 insert (구버전 DB)
    final payload = <String, dynamic>{
      'restaurant_id': restaurantId,
      'level': CrowdLevelMapper.toDb(uiStatus),
      'source': source,
      'metadata': {
        'status': uiStatus,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
      },
    };
    if (_isUuid(userId)) {
      payload['user_id'] = userId;
    }
    await _client.from('crowd_reports').insert(payload);
    return StampResult.none;
  }

  Future<void> reportStatus(
    String restaurantId,
    String uiStatus, {
    String source = 'user',
    String? userId,
    String? nickname,
    double? latitude,
    double? longitude,
  }) async {
    await reportStatusWithStamp(
      restaurantId, uiStatus,
      source: source, userId: userId, nickname: nickname,
      latitude: latitude, longitude: longitude,
    );
  }

  static bool _isUuid(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  Future<DashboardMetrics> fetchMetrics() async {
    try {
      final raw = await _client.rpc('admin_dashboard_metrics');
      if (raw is! Map) {
        throw StateError('admin_dashboard_metrics returned non-object: $raw');
      }
      return _parseMetricsMap(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      debugPrint('[Metrics] RPC failed, using client fallback: $e\n$st');
      return _fetchMetricsClientFallback();
    }
  }

  DashboardMetrics _parseMetricsMap(Map<String, dynamic> map) {
    List<int> parseIntList(dynamic value, int length) {
      if (value is! List) return List.filled(length, 0);
      return value
          .map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
          .toList();
    }

    List<double> parseDoubleList(dynamic value, int length) {
      if (value is! List) return List.filled(length, 0);
      return value
          .map((e) => e is num ? e.toDouble() : double.tryParse('$e') ?? 0)
          .toList();
    }

    Map<String, int> parseCountMap(dynamic value) {
      if (value is! Map) return {};
      return value.map(
        (k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0),
      );
    }

    final topReporters = <(String, int)>[];
    final reportersRaw = map['top_reporters'];
    if (reportersRaw is List) {
      for (final item in reportersRaw) {
        if (item is List && item.length >= 2) {
          topReporters.add((
            item[0]?.toString() ?? '익명',
            item[1] is num ? item[1].toInt() : 0,
          ));
        }
      }
    }

    return DashboardMetrics(
      dauToday: (map['dau_today'] as num?)?.toInt() ?? 0,
      mau: (map['mau'] as num?)?.toInt() ?? 0,
      dailyDau: parseIntList(map['daily_dau'], 7),
      monthlyMau: parseIntList(map['monthly_mau'], 6),
      todayReports: (map['today_reports'] as num?)?.toInt() ?? 0,
      weekReports: (map['week_reports'] as num?)?.toInt() ?? 0,
      bannerClickRate: (map['banner_click_rate'] as num?)?.toDouble() ?? 0,
      dailyClickRates: parseDoubleList(map['daily_click_rates'], 7),
      pushOpenRate: (map['push_open_rate'] as num?)?.toDouble() ?? 0,
      dailyPushOpenRates: parseDoubleList(map['daily_push_open_rates'], 7),
      topReporters: topReporters,
      todayByRestaurant: parseCountMap(map['today_by_restaurant']),
      weekByRestaurant: parseCountMap(map['week_by_restaurant']),
    );
  }

  /// RPC 미적용·실패 시 제보 수만이라도 crowd_reports에서 집계
  Future<DashboardMetrics> _fetchMetricsClientFallback() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));

    final rows = await _client
        .from('crowd_reports')
        .select('created_at, metadata, restaurant_id, source')
        .gte('created_at', weekStart.toUtc().toIso8601String());

    var todayReports = 0;
    var weekReports = 0;
    final todayByRestaurant = <String, int>{};
    final weekByRestaurant = <String, int>{};
    final userCounts = <String, int>{};
    final userNicknames = <String, String>{};

    for (final row in rows) {
      final source = row['source'] as String?;
      if (source != 'user' && source != 'owner') continue;

      final createdAt =
          DateTime.parse(row['created_at'] as String).toLocal();
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final dayIndex = todayStart.difference(day).inDays;

      if (dayIndex >= 0 && dayIndex < 7) {
        weekReports++;
        final rid = row['restaurant_id']?.toString();
        if (rid != null) {
          weekByRestaurant[rid] = (weekByRestaurant[rid] ?? 0) + 1;
        }
      }
      if (dayIndex == 0) {
        todayReports++;
        final rid = row['restaurant_id']?.toString();
        if (rid != null) {
          todayByRestaurant[rid] = (todayByRestaurant[rid] ?? 0) + 1;
        }
        final meta = row['metadata'];
        if (meta is Map) {
          final uid = meta['user_id'] as String?;
          if (uid != null && uid.isNotEmpty) {
            userCounts[uid] = (userCounts[uid] ?? 0) + 1;
            final nick = meta['nickname'] as String?;
            if (nick != null && nick.isNotEmpty) userNicknames[uid] = nick;
          }
        }
      }
    }

    final topReporters = (userCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => (userNicknames[e.key] ?? e.key, e.value))
        .toList();

    return DashboardMetrics(
      dauToday: 0,
      mau: 0,
      dailyDau: List.filled(7, 0),
      monthlyMau: List.filled(6, 0),
      todayReports: todayReports,
      weekReports: weekReports,
      bannerClickRate: 0,
      dailyClickRates: List.filled(7, 0),
      pushOpenRate: 0,
      dailyPushOpenRates: List.filled(7, 0),
      topReporters: topReporters,
      todayByRestaurant: todayByRestaurant,
      weekByRestaurant: weekByRestaurant,
    );
  }

  Future<String?> findRestaurantIdByKakaoPlaceId(String placeId) async {
    final rows = await _client
        .from('restaurants')
        .select('id, description');
    for (final row in rows) {
      final desc = _parseDescription(row['description']);
      final stored = desc?['kakao_place_id'] ?? desc?['google_place_id'];
      if (stored == placeId) {
        return row['id'] as String;
      }
    }
    return null;
  }

  @Deprecated('Use findRestaurantIdByKakaoPlaceId')
  Future<String?> findRestaurantIdByGooglePlaceId(String placeId) =>
      findRestaurantIdByKakaoPlaceId(placeId);

  Future<Restaurant> insert(Map<String, dynamic> data) async {
    final desc = <String, dynamic>{};
    if (data.containsKey('hours')) desc['hours'] = data['hours'];
    if (data.containsKey('hours_display')) {
      desc['hours_display'] = data['hours_display'];
    }
    if (data.containsKey('hours_periods')) {
      desc['hours_periods'] = data['hours_periods'];
    }
    if (data.containsKey('menu')) desc['menu'] = data['menu'];
    if (data.containsKey('kakao_place_id')) {
      desc['kakao_place_id'] = data['kakao_place_id'];
    }
    if (data.containsKey('google_place_id')) {
      desc['google_place_id'] = data['google_place_id'];
    }

    final row = await _client
        .from('restaurants')
        .insert({
          'name': data['name'],
          'category': data['category'],
          'area': data['area'],
          'address': data['address'] ?? data['area'],
          'image_url': data['image_url'] ?? '',
          'description': desc.isEmpty ? '' : jsonEncode(desc),
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
      final desc = _parseDescription(existing['description']) ?? {};
      if (data.containsKey('hours')) desc['hours'] = data['hours'];
      if (data.containsKey('hours_display')) {
        desc['hours_display'] = data['hours_display'];
      }
      if (data.containsKey('hours_periods')) {
        desc['hours_periods'] = data['hours_periods'];
      }
      if (data.containsKey('menu')) desc['menu'] = data['menu'];
      patch['description'] = jsonEncode(desc);
    }

    final rows = await _client
        .from('restaurants')
        .update(patch)
        .eq('id', id)
        .select();
    if ((rows as List).isEmpty) {
      throw Exception('매장 수정 실패: 권한 부족이거나 존재하지 않는 ID');
    }
    final row = Map<String, dynamic>.from(rows.first as Map);

    final reports = await _client
        .from('crowd_reports')
        .select()
        .eq('restaurant_id', id);
    return _mergeRow(row, reports);
  }

  Future<void> delete(String id) async {
    try {
      await _client.rpc('admin_delete_restaurant', params: {
        'p_restaurant_id': id,
      });
      return;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202' &&
          !e.message.contains('admin_delete_restaurant') &&
          !e.message.contains('Could not find')) {
        rethrow;
      }
    }

    // RPC 미적용 DB: 관련 데이터 후 직접 DELETE (restaurants_delete_admin 정책 필요)
    await _client.from('crowd_reports').delete().eq('restaurant_id', id);
    await _client.from('owner_seat_updates').delete().eq('restaurant_id', id);
    await _client.from('crowd_status').delete().eq('restaurant_id', id);
    await _client.from('analytics_events').delete().eq('restaurant_id', id);

    final deleted = await _client
        .from('restaurants')
        .delete()
        .eq('id', id)
        .select('id');
    if ((deleted as List).isEmpty) {
      throw Exception(
        '매장 삭제 실패: supabase/rpc_admin_restaurants.sql 실행·관리자 권한 확인',
      );
    }
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
    List<Map<String, dynamic>> reports, {
    Map<String, dynamic>? crowdStatus,
    DateTime? now,
    DateTime? ownerUpdatedAt,
    bool isOpen = true,
  }) {
    final at = now ?? DateTime.now();
    final id = row['id'] as String;
    final extra = _parseDescription(row['description']);
    final bh = BusinessHoursData.fromDescription(extra);
    final sessionStart = bh.sessionStartAt(at);

    // 이번 영업 세션 시작 이후 제보만 유효
    final sessionReports = sessionStart != null
        ? reports.where((r) {
            final createdAt = r['created_at'] as String?;
            if (createdAt == null) return false;
            return DateTime.parse(createdAt).toLocal().isAfter(sessionStart);
          }).toList()
        : reports;

    final hasReports = sessionReports.isNotEmpty;

    final computed = computeStatusFromReports(
      reports: sessionReports,
      existingStatus: crowdStatus,
      now: at,
      businessSessionStart: sessionStart,
    );

    late final String finalStatus;
    var updated = 0;
    DateTime? updatedAt;
    var hasCrowdUpdate = false;

    // 제보필요 기준: 이번 영업 세션 시작 이후 제보가 하나라도 있는가.
    // crowd_status.updated_at(캐시값)은 신뢰하지 않음 — 과거 세션의 흔적이 남아있을 수 있어서
    // 이번 세션에 제보가 없어도 "업데이트됨"으로 잘못 판정되는 문제가 있었음.
    if (hasReports) {
      finalStatus = computed.displayStatus;
      // 업데이트 시간: 이번 세션 제보 중 가장 최신 시각 기준
      final latestReportTime = sessionReports
          .map((r) => DateTime.parse(r['created_at'] as String).toLocal())
          .reduce((a, b) => a.isAfter(b) ? a : b);
      updated = at.difference(latestReportTime).inMinutes.clamp(0, 99999);
      updatedAt = latestReportTime;
      hasCrowdUpdate = true;
    } else {
      // 이번 세션에 제보가 하나도 없음 → 제보필요
      finalStatus = computed.displayStatus;
      hasCrowdUpdate = false;
    }

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
        : <MenuItem>[];

    final menuPhotoList = extra?['menu_photo_urls'];
    final menuPhotoUrls = menuPhotoList is List
        ? menuPhotoList.map((e) => e.toString()).toList()
        : <String>[];

    return Restaurant(
      id: id,
      linkNo: (row['link_no'] as num?)?.toInt() ?? 0,
      name: row['name'] as String,
      category: row['category'] as String,
      area: row['area'] as String,
      address: row['address'] as String? ?? row['area'] as String,
      status: finalStatus,
      imageUrl: row['image_url'] as String? ?? '',
      distance: (extra?['distance'] as num?)?.toDouble() ?? 200,
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      x: (extra?['map_x'] as num?)?.toDouble() ?? 50,
      y: (extra?['map_y'] as num?)?.toDouble() ?? 50,
      hours: _hoursLabel(extra, null),
      hoursPeriods: BusinessHoursData.fromDescription(extra).periods,
      reports: reportCounts,
      menu: menu,
      popularityScore: _calcPopularityScore(
        reports,
        extra?['hours'] as String? ?? '',
      ),
      manualRank: (extra?['manual_rank'] as num?)?.toInt() ?? 0,
      ownerId: row['owner_id'] as String?,
      crowdBaseSource: crowdMetaString(crowdStatus, 'base_source') ?? '',
      crowdConfidence: crowdMetaString(crowdStatus, 'confidence') ?? '',
      // 좌석 업데이트는 상세 카드 전용. 혼잡도 뱃지(hasCrowdUpdate)와 섞지 않는다.
      hasCrowdUpdate: hasCrowdUpdate,
      updated: updated,
      updatedAt: updatedAt,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)?.toLocal()
          : null,
      ownerUpdatedAt: ownerUpdatedAt,
      isActive: row['is_active'] as bool? ?? true,
      menuPhotoUrls: menuPhotoUrls,
      imageSource: extra?['image_source'] as String? ?? 'google',
      googleImageUrl: extra?['google_image_url'] as String? ?? '',
      ownerNotice: extra?['owner_notice'] as String? ?? '',
    );
  }

  Future<List<RecentCrowdReport>> fetchRecentReports(
    String restaurantId, {
    int limit = 20,
  }) async {
    final rows = await _client
        .from('crowd_reports')
        .select('id, level, source, metadata, created_at, user_id')
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final meta = Map<String, dynamic>.from(row['metadata'] as Map? ?? {});
      return RecentCrowdReport(
        id: row['id'] as String,
        status: CrowdLevelMapper.fromDb(
          row['level'] as String,
          metadata: meta,
        ),
        source: row['source'] as String? ?? 'user',
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        userId: row['user_id'] as String?,
      );
    }).toList();
  }

  Future<OwnerSeatUpdate?> fetchOwnerSeatUpdate(String restaurantId) async {
    try {
      final raw = await _client.rpc(
        'get_owner_seat_update',
        params: {'p_restaurant_id': restaurantId},
      );
      if (raw is List && raw.isNotEmpty) {
        return OwnerSeatUpdate.fromMap(
          Map<String, dynamic>.from(raw.first as Map),
        );
      }
    } catch (e, st) {
      debugPrint('[Supabase] fetchOwnerSeatUpdate failed: $e\n$st');
    }
    return null;
  }

  Future<OwnerSeatUpdate?> fetchLatestOwnerSeatUpdate(
    String restaurantId,
  ) async {
    try {
      final row = await _client
          .from('owner_seat_updates')
          .select('available_seats, created_at')
          .eq('restaurant_id', restaurantId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return OwnerSeatUpdate.fromMap(Map<String, dynamic>.from(row));
    } catch (e, st) {
      debugPrint('[Supabase] fetchLatestOwnerSeatUpdate failed: $e\n$st');
      return null;
    }
  }

  Future<void> submitOwnerSeatUpdate(
    String restaurantId,
    int availableSeats, {
    double? latitude,
    double? longitude,
  }) async {
    await _client.rpc(
      'submit_owner_seat_update',
      params: {
        'p_restaurant_id': restaurantId,
        'p_available_seats': availableSeats,
        'p_lat': latitude,
        'p_lng': longitude,
      },
    );
  }

  /// 사장님 인증 신청 제출 (가게 선택 + 사업자등록증 + 연락처)
  Future<void> submitOwnerApplication({
    required String restaurantId,
    required String phone,
    required String email,
    required List<String> licensePaths,
    bool notifyPush = false,
    bool notifySms = false,
  }) async {
    await _client.rpc('submit_owner_application', params: {
      'p_restaurant_id': restaurantId,
      'p_phone': phone,
      'p_email': email,
      'p_license_paths': licensePaths,
      'p_notify_push': notifyPush,
      'p_notify_sms': notifySms,
    });
  }

  /// 내 최신 사장님 인증 신청 상태 (없으면 null)
  Future<Map<String, dynamic>?> fetchMyOwnerApplication() async {
    final rows = await _client.rpc('get_my_owner_application');
    if (rows is List && rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return null;
  }

  /// 사업자등록증 이미지 업로드 (private 버킷, 본인 폴더 하위). 실패 시 예외를 그대로 전파.
  Future<String> uploadOwnerLicenseImage(Uint8List bytes, String ext) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('로그인이 필요해요.');
    const bucket = 'owner-licenses';
    final path =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000000)}.$ext';
    await _client.storage.from(bucket).uploadBinary(
          path, bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
        );
    return path;
  }

  /// 본인 소유 매장 등록 해제 (owner_id 초기화)
  Future<void> releaseOwnerRestaurant(String restaurantId) async {
    await _client.rpc(
      'release_owner_restaurant',
      params: {'p_restaurant_id': restaurantId},
    );
  }

  /// DB 기준 본인 소유 매장 ID (restaurants.owner_id)
  Future<List<String>> fetchOwnedRestaurantIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('restaurants')
          .select('id')
          .eq('is_active', true)
          .eq('owner_id', uid);
      return rows.map((row) => row['id'] as String).toList();
    } catch (e, st) {
      debugPrint('[Supabase] fetchOwnedRestaurantIds failed: $e\n$st');
      return [];
    }
  }

  Future<String> uploadImage(
    Uint8List bytes,
    String ext, {
    bool allowBase64Fallback = true,
  }) async {
    const bucket = 'restaurant-images';
    final path = 'restaurants/${DateTime.now().millisecondsSinceEpoch}.$ext';

    // Storage 업로드 시도 (버킷 없으면 자동 생성 후 재시도)
    try {
      try {
        await _client.storage.createBucket(
          bucket,
          const BucketOptions(public: true),
        );
      } catch (_) {
        // 이미 존재하면 무시
      }
      await _client.storage.from(bucket).uploadBinary(
            path, bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      if (!allowBase64Fallback) rethrow;
      // Storage 실패 시 base64로 DB에 직접 저장
      debugPrint('[Storage] fallback to base64: $e');
      return 'data:image/$ext;base64,${base64Encode(bytes)}';
    }
  }

  /// 사장님이 매장 관리 탭에서 올리는 사진 전용 — base64 폴백을 쓰면 여러 장의
  /// 이미지가 restaurants row(description)에 그대로 박혀 fetchAll() 응답이
  /// 비대해지므로, Storage 업로드가 실패하면 폴백 없이 예외를 던진다.
  Future<String> uploadOwnerPhoto(Uint8List bytes, String ext) {
    return uploadImage(bytes, ext, allowBase64Fallback: false);
  }

  /// 사장님 매장 관리(사진/메뉴/영업시간/공지) — owner_update_restaurant RPC.
  /// 각 파라미터는 null이면 미변경.
  Future<void> ownerUpdateRestaurant(
    String restaurantId, {
    String? imageUrl,
    String? imageSource,
    List<String>? menuPhotoUrls,
    List<MenuItem>? menu,
    String? hours,
    String? hoursDisplay,
    String? ownerNotice,
  }) async {
    await _client.rpc('owner_update_restaurant', params: {
      'p_restaurant_id': restaurantId,
      if (imageUrl != null) 'p_image_url': imageUrl,
      if (imageSource != null) 'p_image_source': imageSource,
      if (menuPhotoUrls != null) 'p_menu_photo_urls': menuPhotoUrls,
      if (menu != null) 'p_menu': menu.map((m) => m.toMap()).toList(),
      if (hours != null) 'p_hours': hours,
      if (hoursDisplay != null) 'p_hours_display': hoursDisplay,
      if (ownerNotice != null) 'p_owner_notice': ownerNotice,
    });
  }

  Future<void> updateManualRanks(Map<String, int> rankById) async {
    for (final entry in rankById.entries) {
      final existing = await _client
          .from('restaurants')
          .select('description')
          .eq('id', entry.key)
          .single();
      final desc = _parseDescription(existing['description']) ?? {};
      desc['manual_rank'] = entry.value;
      final updated = await _client
          .from('restaurants')
          .update({'description': jsonEncode(desc)})
          .eq('id', entry.key)
          .select('id');
      if ((updated as List).isEmpty) {
        throw Exception('순위 저장 실패: ${entry.key}');
      }
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

  String _hoursLabel(Map<String, dynamic>? extra, String? seedHours) {
    final hours = extra?['hours'] as String?;
    if (hours != null && hours.trim().isNotEmpty) return hours.trim();
    return seedHours ?? BusinessHoursData.defaultHours;
  }

  List<(int, int)> _parseHoursRanges(String hours) =>
      BusinessHoursData.parseCanonicalRanges(hours);

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

  Map<String, dynamic>? _parseDescription(dynamic raw) {
    if (raw == null) return null;
    // jsonb 컬럼이면 이미 Map으로 반환됨
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final str = raw as String?;
    if (str == null || str.isEmpty) return null;
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

}
