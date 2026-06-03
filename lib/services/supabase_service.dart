import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class SupabaseService {
  static bool _initialized = false;

  static bool get isReady => _initialized && Env.isSupabaseConfigured;

  static SupabaseClient get client => Supabase.instance.client;

  /// Supabase Auth JWT `app_metadata.role` 또는 `user_metadata.role` 이 admin 인지
  static bool get isAdmin {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final appRole = user.appMetadata['role'];
    final userRole = user.userMetadata?['role'];
    return appRole == 'admin' || userRole == 'admin';
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
