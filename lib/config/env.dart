import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 클라이언트용 설정 (.env — Publishable / Maps 키만)
class Env {
  static final Map<String, String> _releaseFallback = {};
  static bool kakaoMapSdkInitialized = false;

  /// APK 릴리스에서 .env 로드 실패 시 assets/config/native_keys.json 폴백
  static Future<void> loadReleaseConfig() async {
    try {
      final raw = await rootBundle.loadString('assets/config/native_keys.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final v = entry.value?.toString().trim() ?? '';
        if (v.isNotEmpty) {
          _releaseFallback[entry.key] = v;
        }
      }
      if (kDebugMode && _releaseFallback.isNotEmpty) {
        debugPrint(
          '[Env] release fallback keys: ${_releaseFallback.keys.join(', ')}',
        );
      }
    } catch (e) {
      debugPrint('[Env] native_keys.json load failed: $e');
    }
  }

  @Deprecated('Use loadReleaseConfig')
  static Future<void> loadNativeKeyFallback() => loadReleaseConfig();

  static String _get(String key) {
    final fromEnv = dotenv.env[key]?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
    return _releaseFallback[key] ?? '';
  }

  static String get supabaseUrl => _get('SUPABASE_URL');

  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get googleMapsApiKey => _get('GOOGLE_MAPS_API_KEY');

  static bool get isGooglePlacesConfigured => googleMapsApiKey.isNotEmpty;

  static String get kakaoNativeAppKey => _get('KAKAO_NATIVE_APP_KEY');

  /// 카카오 로컬·모빌리티 REST API (장소 검색, 길찾기). Native App Key로는 동작하지 않음.
  static String get kakaoRestApiKey => _get('KAKAO_REST_API_KEY');

  static bool get isKakaoConfigured => kakaoNativeAppKey.isNotEmpty;

  static bool get isKakaoLocalConfigured => kakaoRestApiKey.isNotEmpty;

  /// 카카오 모빌리티 제휴 도보 길찾기 service 이름 (레거시 Kakao API용)
  static String get kakaoMobilityService =>
      dotenv.env['KAKAO_MOBILITY_SERVICE']?.trim() ?? '';

  /// OSRM 서버 URL (미설정 시 공용 demo 서버). 예: https://router.project-osrm.org
  static String get osrmBaseUrl => _get('OSRM_BASE_URL');

  static bool get isKakaoMapConfigured =>
      kakaoNativeAppKey.isNotEmpty && kakaoMapSdkInitialized;

  static bool get hasKakaoNativeKey => kakaoNativeAppKey.isNotEmpty;

  static String get kakaoJavascriptKey => _get('KAKAO_JAVASCRIPT_KEY');

  /// Google Cloud OAuth 2.0 — **웹** Client ID (Android serverClientId + Supabase)
  static String get googleOAuthWebClientId => _get('GOOGLE_OAUTH_WEB_CLIENT_ID');

  /// Google Cloud OAuth 2.0 — **iOS** Client ID
  static String get googleOAuthIosClientId => _get('GOOGLE_OAUTH_IOS_CLIENT_ID');

  static bool get isGoogleOAuthConfigured =>
      googleOAuthWebClientId.isNotEmpty;
}
