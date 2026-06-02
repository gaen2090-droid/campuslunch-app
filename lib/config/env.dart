import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 클라이언트용 설정 (.env — Publishable / Maps 키만)
class Env {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL']?.trim() ?? '';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;

  /// 이메일 인증 후 바로 앱으로 돌아오는 주소 (웹 배포 불필요)
  /// Supabase Redirect URLs / Site URL 에 동일하게 등록
  static String get authRedirectUrl =>
      dotenv.env['AUTH_REDIRECT_URL']?.trim().isNotEmpty == true
          ? dotenv.env['AUTH_REDIRECT_URL']!.trim()
          : 'campuslunch://login-callback';
}
