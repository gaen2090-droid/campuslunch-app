import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class SupabaseService {
  static bool _initialized = false;

  static bool get isReady => _initialized && Env.isSupabaseConfigured;

  static SupabaseClient get client => Supabase.instance.client;

  /// 관리자 여부 — public.users.role 만 신뢰 (JWT user_metadata는 사용하지 않음)
  static bool get isAdmin {
    // 동기 호출용; 정본은 AppProvider._userRole (DB fetch 후)
    return false;
  }

  static Future<void> initialize() async {
    if (!Env.isSupabaseConfigured) return;
    if (_initialized) return;

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    _initialized = true;
    debugPrint('[Supabase] initialized (email OTP auth)');
  }
}
