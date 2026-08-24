import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class AnalyticsRepository {
  AnalyticsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<void> recordAppSession() async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc('record_app_session');
    } catch (e, st) {
      debugPrint('[Analytics] recordAppSession: $e\n$st');
    }
  }

  Future<void> recordBannerImpression(String restaurantId) async {
    await _recordBanner('banner_impression', restaurantId);
  }

  Future<void> recordBannerClick(String restaurantId) async {
    await _recordBanner('banner_click', restaurantId);
  }

  Future<void> recordMapMarkerClick(String restaurantId) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    if (restaurantId.isEmpty) return;
    try {
      await _client.rpc(
        'record_map_marker_click',
        params: {'p_restaurant_id': restaurantId},
      );
    } catch (e, st) {
      debugPrint('[Analytics] map_marker_click: $e\n$st');
    }
  }

  /// 홈/지도 검색 결과에서 이 매장을 선택(클릭)했을 때 기록
  Future<void> recordSearchResultClick(String restaurantId) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    if (restaurantId.isEmpty) return;
    try {
      await _client.rpc(
        'record_search_result_click',
        params: {'p_restaurant_id': restaurantId},
      );
    } catch (e, st) {
      debugPrint('[Analytics] search_result_click: $e\n$st');
    }
  }

  /// 매장 상세페이지 진입 시 기록 (사장님 본인 매장 미리보기는 호출측에서 제외)
  Future<void> recordDetailView(String restaurantId) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    if (restaurantId.isEmpty) return;
    try {
      await _client.rpc(
        'record_detail_view',
        params: {'p_restaurant_id': restaurantId},
      );
    } catch (e, st) {
      debugPrint('[Analytics] detail_view: $e\n$st');
    }
  }

  Future<void> recordPushDelivered({
    required String slot,
    String? restaurantId,
    required String dayKey,
  }) async {
    await _recordPush(
      'push_delivered',
      restaurantId: restaurantId,
      metadata: {'slot': slot, 'day_key': dayKey},
    );
  }

  Future<void> recordPushClick({
    required String slot,
    String? restaurantId,
  }) async {
    await _recordPush(
      'push_click',
      restaurantId: restaurantId,
      metadata: {'slot': slot},
    );
  }

  Future<void> _recordPush(
    String event, {
    String? restaurantId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc(
        'record_push_event',
        params: {
          'p_event': event,
          'p_restaurant_id': restaurantId,
          'p_metadata': metadata ?? {},
        },
      );
    } catch (e, st) {
      debugPrint('[Analytics] $event: $e\n$st');
    }
  }

  Future<void> recordReportAttempt({
    required String restaurantId,
    required bool success,
    String? failReason,
    String? deviceInstallId,
    String? appSessionId,
    double? latitude,
    double? longitude,
    String source = 'user',
    String? status,
  }) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc(
        'record_report_attempt',
        params: {
          'p_restaurant_id': restaurantId,
          'p_outcome': success ? 'success' : 'fail',
          'p_fail_reason': failReason,
          'p_device_install_id': deviceInstallId,
          'p_app_session_id': appSessionId,
          'p_lat': latitude,
          'p_lng': longitude,
          'p_source': source,
          'p_status': status,
          'p_metadata': <String, dynamic>{},
        },
      );
    } catch (e, st) {
      debugPrint('[Analytics] recordReportAttempt: $e\n$st');
    }
  }

  Future<void> recordScreenDwell({
    required String screen,
    required int dwellMs,
    String? appSessionId,
  }) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    if (dwellMs < 2000) return;
    try {
      await _client.rpc(
        'record_screen_dwell',
        params: {
          'p_screen': screen,
          'p_dwell_ms': dwellMs,
          'p_app_session_id': appSessionId,
          'p_metadata': <String, dynamic>{},
        },
      );
    } catch (e, st) {
      debugPrint('[Analytics] recordScreenDwell: $e\n$st');
    }
  }

  Future<void> _recordBanner(String event, String restaurantId) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    if (restaurantId.isEmpty) return;
    try {
      await _client.rpc(
        'record_banner_event',
        params: {
          'p_event': event,
          'p_restaurant_id': restaurantId,
        },
      );
    } catch (e, st) {
      debugPrint('[Analytics] $event: $e\n$st');
    }
  }
}
