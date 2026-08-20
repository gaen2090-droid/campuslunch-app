import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../data/auth_repository.dart';
import 'google_auth_service.dart';
import 'supabase_service.dart';

class KakaoAuthResult {
  final User user;
  final String? profileImageUrl;

  const KakaoAuthResult({
    required this.user,
    this.profileImageUrl,
  });
}

class KakaoAuthService {
  static bool get isConfigured => Env.isKakaoConfigured;
  static bool _initialized = false;
  static Future<KakaoAuthResult>? _signInInFlight;

  static void _logIdTokenClaims(String idToken) {
    if (!kDebugMode) return;
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      debugPrint('[Kakao] id_token claims: $payload');
    } catch (e) {
      debugPrint('[Kakao] id_token decode skipped: $e');
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!isConfigured) {
      debugPrint('[Kakao] KAKAO_NATIVE_APP_KEY 없음 — .env / keys.properties 확인');
      return;
    }
    final key = Env.kakaoNativeAppKey;
    if (!_looksLikeNativeAppKey(key)) {
      debugPrint(
        '[Kakao] 키 형식이 이상합니다(32자 hex 아님). '
        'REST API 키가 아닌 네이티브 앱 키인지 확인하세요. len=${key.length}',
      );
    }
    KakaoSdk.init(nativeAppKey: key);
    _initialized = true;
    debugPrint('[Kakao] SDK initialized (key …${key.substring(key.length - 4)})');
  }

  static bool _looksLikeNativeAppKey(String key) =>
      RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(key);

  /// 카카오 로그인 → Supabase Auth 세션 (로그인 유지는 Supabase가 처리)
  /// 닉네임은 AppProvider에서 앙대+과일+숫자 형식으로 생성
  static Future<KakaoAuthResult> signInWithSupabase() async {
    if (_signInInFlight != null) {
      debugPrint('[Kakao] signInWithSupabase already in progress — waiting');
      return _signInInFlight!;
    }
    final future = _signInWithSupabaseImpl();
    _signInInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_signInInFlight, future)) {
        _signInInFlight = null;
      }
    }
  }

  static Future<KakaoAuthResult> _signInWithSupabaseImpl() async {
    if (!isConfigured) {
      throw Exception('카카오 로그인을 사용할 수 없어요.');
    }
    if (!SupabaseService.isReady) {
      throw Exception('서버 연결에 실패했어요.');
    }
    await initialize();

    final token = await _loginWithKakao();
    final idToken = token.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        '카카오 OpenID 토큰이 없습니다. 카카오 개발자 콘솔에서 OpenID Connect를 켜고 '
        'Supabase Auth에 Kakao 제공자를 설정해주세요.',
      );
    }
    debugPrint('[Kakao] signInWithIdToken start');
    _logIdTokenClaims(idToken);

    try {
      debugPrint('[Kakao] me() start');
      final me = await UserApi.instance.me();
      final email = me.kakaoAccount?.email ?? '';
      debugPrint('[Kakao] me() ok (email=${email.isNotEmpty})');
      if (email.isNotEmpty) {
        final status =
            await AuthRepository().checkOAuthLoginEmail(email, 'kakao');
        debugPrint('[Kakao] oauth_login_email_check=$status');
        switch (status) {
          case OAuthLoginEmailStatus.available:
          case OAuthLoginEmailStatus.sameProvider:
          case OAuthLoginEmailStatus.unknown:
            break;
          case OAuthLoginEmailStatus.blockedEmail:
          case OAuthLoginEmailStatus.blockedOther:
          case OAuthLoginEmailStatus.pending:
          case OAuthLoginEmailStatus.withdrawn:
          case OAuthLoginEmailStatus.invalid:
            await UserApi.instance.logout();
            throw GoogleEmailBlocked(status);
        }
      }
    } on GoogleEmailBlocked {
      rethrow;
    } catch (e) {
      debugPrint('[Kakao] pre-auth email check: $e');
    }

    try {
      debugPrint('[Kakao] supabase signInWithIdToken request');
      final authRes = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: idToken,
        accessToken: token.accessToken,
      );
      debugPrint('[Kakao] signInWithIdToken ok (user=${authRes.user?.id})');
      final user = authRes.user;
      if (user == null) {
        throw Exception('Supabase 로그인에 실패했습니다.');
      }

      final kakaoProfile = await _fetchKakaoProfile();

      await SupabaseService.client.auth.updateUser(
        UserAttributes(
          data: {
            'auth_provider': 'kakao',
            if (kakaoProfile.kakaoUserId != null)
              'kakao_user_id': kakaoProfile.kakaoUserId,
            if (kakaoProfile.profileImageUrl != null)
              'avatar_url': kakaoProfile.profileImageUrl,
          },
        ),
      );

      final refreshed = SupabaseService.client.auth.currentUser ?? user;
      return KakaoAuthResult(
        user: refreshed,
        profileImageUrl: kakaoProfile.profileImageUrl,
      );
    } on AuthException catch (e, st) {
      debugPrint(
        '[Kakao] signInWithIdToken AuthException: ${e.message} '
        'status=${e.statusCode} code=${e.code}\n$st',
      );
      rethrow;
    }
  }

  static Future<OAuthToken> _loginWithKakao() async {
    final talkInstalled = await isKakaoTalkInstalled();
    debugPrint('[Kakao] login start (talkInstalled=$talkInstalled)');
    if (talkInstalled) {
      try {
        final token = await UserApi.instance.loginWithKakaoTalk();
        debugPrint(
          '[Kakao] talk login ok (idToken=${token.idToken != null && token.idToken!.isNotEmpty})',
        );
        return token;
      } catch (e) {
        if (_isUserCancelled(e)) rethrow;
        debugPrint('[Kakao] Talk login failed, fallback to account: $e');
      }
    }
    debugPrint('[Kakao] account login start');
    final token = await UserApi.instance.loginWithKakaoAccount();
    debugPrint(
      '[Kakao] account login ok (idToken=${token.idToken != null && token.idToken!.isNotEmpty})',
    );
    return token;
  }

  static Future<({
    String? profileImageUrl,
    String? kakaoUserId,
  })> _fetchKakaoProfile() async {
    try {
      final me = await UserApi.instance.me();
      final account = me.kakaoAccount;
      final profile = account?.profile;
      return (
        profileImageUrl: profile?.thumbnailImageUrl ?? profile?.profileImageUrl,
        kakaoUserId: me.id?.toString(),
      );
    } catch (e) {
      debugPrint('[Kakao] me() failed: $e');
      return (profileImageUrl: null, kakaoUserId: null);
    }
  }

  /// 카카오 SDK 로그아웃 (Supabase signOut은 AppProvider에서)
  static Future<void> logoutKakao() async {
    if (!isConfigured) return;
    try {
      await UserApi.instance.logout();
    } catch (e) {
      debugPrint('[Kakao] logout: $e');
    }
  }

  static bool _isUserCancelled(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('cancel') ||
        m.contains('canceled') ||
        m.contains('cancelled') ||
        m.contains('user_canceled');
  }

  static Future<void> unlinkKakao() async {
    if (!isConfigured) return;
    try {
      await UserApi.instance.unlink();
    } catch (e) {
      debugPrint('[Kakao] unlink: $e');
      rethrow;
    }
  }
}
