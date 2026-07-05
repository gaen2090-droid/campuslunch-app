import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/push_notification_config.dart';
import '../services/supabase_service.dart';

class PushConfigRepository {
  PushConfigRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<PushNotificationConfig> fetchConfig() async {
    if (!SupabaseService.isReady) return PushNotificationConfig.defaults;
    try {
      final raw = await _client.rpc('get_push_notification_config');
      if (raw is Map<String, dynamic>) {
        return PushNotificationConfig.fromJson(raw);
      }
      if (raw is Map) {
        return PushNotificationConfig.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }
    } catch (e, st) {
      debugPrint('[PushConfig] fetch failed: $e\n$st');
    }
    return PushNotificationConfig.defaults;
  }
}
