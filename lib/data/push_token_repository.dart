import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';

class PushTokenRepository {
  Future<void> upsertToken({
    required String token,
    required String platform,
  }) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.rpc(
      'upsert_push_token',
      params: {'p_token': token, 'p_platform': platform},
    );
  }

  Future<void> deleteToken(String token) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.rpc(
      'delete_push_token',
      params: {'p_token': token},
    );
  }

  Future<void> upsertPrefs({
    required bool peakLunch,
    required bool peakDinner,
    required bool communityComments,
  }) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.rpc(
      'upsert_notification_prefs',
      params: {
        'p_peak_lunch': peakLunch,
        'p_peak_dinner': peakDinner,
        'p_community_comments': communityComments,
      },
    );
  }

  Future<({bool peakLunch, bool peakDinner, bool communityComments})?>
      fetchPrefs() async {
    if (!SupabaseService.isReady) return null;
    final row = await SupabaseService.client.rpc('get_notification_prefs');
    if (row is! Map) return null;
    final map = Map<String, dynamic>.from(row);
    return (
      peakLunch: map['peak_lunch'] as bool? ?? true,
      peakDinner: map['peak_dinner'] as bool? ?? true,
      communityComments: map['community_comments'] as bool? ?? true,
    );
  }

  static String currentPlatformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}
