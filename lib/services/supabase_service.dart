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
      // 카카오톡 OAuth 복귀 URL(`kakao{KEY}://oauth?code=`)도 `code`를 포함해
      // supabase_flutter 기본 딥링크 처리와 충돌한다. 이메일 매직링크는
      // AppLinkService에서 campuslunch://login-callback 만 수동 처리한다.
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
      ),
    );
    _initialized = true;
    debugPrint('[Supabase] initialized (auth deeplink via AppLinkService)');
  }
}
