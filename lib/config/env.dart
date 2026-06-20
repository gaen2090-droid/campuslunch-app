import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

/// 앱 클라이언트용 설정 (.env — Publishable / Maps 키만)
class Env {
  static String _nativeKakaoKeyFallback = '';

  /// .env 가 APK에 없을 때 assets/config/native_keys.json 사용
  static Future<void> loadNativeKeyFallback() async {
    if ((dotenv.env['KAKAO_NATIVE_APP_KEY']?.trim() ?? '').isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString('assets/config/native_keys.json');
      final match = RegExp(r'"KAKAO_NATIVE_APP_KEY"\s*:\s*"([^"]+)"')
          .firstMatch(raw);
      _nativeKakaoKeyFallback = match?.group(1)?.trim() ?? '';
    } catch (_) {}
  }

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL']?.trim() ?? '';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';

  static bool get isGooglePlacesConfigured => googleMapsApiKey.isNotEmpty;

  static String get kakaoNativeAppKey {
    final fromEnv = dotenv.env['KAKAO_NATIVE_APP_KEY']?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
    return _nativeKakaoKeyFallback;
  }

  /// 카카오 로컬·모빌리티 REST API (장소 검색, 길찾기). Native App Key로는 동작하지 않음.
  static String get kakaoRestApiKey =>
      dotenv.env['KAKAO_REST_API_KEY']?.trim() ?? '';

  static bool get isKakaoConfigured => kakaoNativeAppKey.isNotEmpty;

  static bool get isKakaoLocalConfigured => kakaoRestApiKey.isNotEmpty;

  /// 카카오 모빌리티 제휴 도보 길찾기 service 이름 (레거시 Kakao API용)
  static String get kakaoMobilityService =>
      dotenv.env['KAKAO_MOBILITY_SERVICE']?.trim() ?? '';

  /// OSRM 서버 URL (미설정 시 공용 demo 서버). 예: https://router.project-osrm.org
  static String get osrmBaseUrl =>
      dotenv.env['OSRM_BASE_URL']?.trim() ?? '';

  static bool get isKakaoMapConfigured => kakaoNativeAppKey.isNotEmpty;

  static String get kakaoJavascriptKey =>
      dotenv.env['KAKAO_JAVASCRIPT_KEY']?.trim() ?? '';

  /// Google Cloud OAuth 2.0 — **웹** Client ID (Android serverClientId + Supabase)
  static String get googleOAuthWebClientId =>
      dotenv.env['GOOGLE_OAUTH_WEB_CLIENT_ID']?.trim() ?? '';

  /// Google Cloud OAuth 2.0 — **iOS** Client ID
  static String get googleOAuthIosClientId =>
      dotenv.env['GOOGLE_OAUTH_IOS_CLIENT_ID']?.trim() ?? '';

  static bool get isGoogleOAuthConfigured =>
      googleOAuthWebClientId.isNotEmpty;
}
