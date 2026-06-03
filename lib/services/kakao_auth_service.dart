import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
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

  static Future<void> initialize() async {
    if (!isConfigured) return;
    KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
    debugPrint('[Kakao] SDK initialized');
  }

  /// 카카오 로그인 → Supabase Auth 세션 (로그인 유지는 Supabase가 처리)
  /// 닉네임은 AppProvider에서 앙대+과일+숫자 형식으로 생성
  static Future<KakaoAuthResult> signInWithSupabase() async {
    if (!isConfigured) {
      throw Exception('KAKAO_NATIVE_APP_KEY가 .env에 없습니다.');
    }
    if (!SupabaseService.isReady) {
      throw Exception('Supabase가 설정되지 않았습니다.');
    }

    final token = await _loginWithKakao();
    final idToken = token.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        '카카오 OpenID 토큰이 없습니다. 카카오 개발자 콘솔에서 OpenID Connect를 켜고 '
        'Supabase Auth에 Kakao 제공자를 설정해주세요.',
      );
    }

    final authRes = await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: idToken,
      accessToken: token.accessToken,
    );
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
  }

  static Future<OAuthToken> _loginWithKakao() async {
    final talkInstalled = await isKakaoTalkInstalled();
    if (talkInstalled) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        if (_isUserCancelled(e)) rethrow;
        debugPrint('[Kakao] Talk login failed, fallback to account: $e');
      }
    }
    return await UserApi.instance.loginWithKakaoAccount();
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

  /// 회원 탈퇴: 카카오 연결 해제
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
