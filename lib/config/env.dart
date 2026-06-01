import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 클라이언트용 Supabase 설정 (.env — Publishable 키만)
class Env {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL']?.trim() ?? '';

  /// Dashboard > API Keys > Publishable (`sb_publishable_...`)
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
