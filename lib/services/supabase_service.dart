import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class SupabaseService {
  static bool _initialized = false;

  static bool get isReady => _initialized && Env.isSupabaseConfigured;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!Env.isSupabaseConfigured) return;
    if (_initialized) return;

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    _initialized = true;
  }
}
