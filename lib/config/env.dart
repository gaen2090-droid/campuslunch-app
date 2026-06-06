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

  static String get kakaoNativeAppKey =>
      dotenv.env['KAKAO_NATIVE_APP_KEY']?.trim() ?? '';

  static bool get isKakaoConfigured => kakaoNativeAppKey.isNotEmpty;

  /// Google Cloud OAuth 2.0 — **웹** Client ID (Android serverClientId + Supabase)
  static String get googleOAuthWebClientId =>
      dotenv.env['GOOGLE_OAUTH_WEB_CLIENT_ID']?.trim() ?? '';

  /// Google Cloud OAuth 2.0 — **iOS** Client ID
  static String get googleOAuthIosClientId =>
      dotenv.env['GOOGLE_OAUTH_IOS_CLIENT_ID']?.trim() ?? '';

  static bool get isGoogleOAuthConfigured =>
      googleOAuthWebClientId.isNotEmpty;
}
