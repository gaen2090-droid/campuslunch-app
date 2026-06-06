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
