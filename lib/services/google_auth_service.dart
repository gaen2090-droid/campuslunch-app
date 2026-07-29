import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../data/auth_repository.dart';
import 'supabase_service.dart';

class GoogleAuthResult {
  final User user;
  final String? profileImageUrl;
  final String? displayName;

  const GoogleAuthResult({
    required this.user,
    this.profileImageUrl,
    this.displayName,
  });
}

class GoogleSignInCancelled implements Exception {
  @override
  String toString() => 'Google sign-in cancelled';
}

class GoogleEmailBlocked implements Exception {
  final OAuthLoginEmailStatus status;

  const GoogleEmailBlocked(this.status);
}

class GoogleAuthService {
  static bool _initialized = false;

  static bool get isConfigured => Env.isGoogleOAuthConfigured;

  static String? get _iosClientId =>
      (!kIsWeb && Platform.isIOS && Env.googleOAuthIosClientId.isNotEmpty)
          ? Env.googleOAuthIosClientId
          : null;

  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint(
        '[Google] 웹(Chrome)은 지원하지 않습니다. iOS/Android 시뮬레이터로 실행하세요.',
      );
      return;
    }
    if (!isConfigured) {
      debugPrint(
        '[Google] GOOGLE_OAUTH_WEB_CLIENT_ID 없음 — .env / docs/GOOGLE_SUPABASE_SETUP.md 확인',
      );
      return;
    }
    if (_initialized) return;

    await GoogleSignIn.instance.initialize(
      serverClientId: Env.googleOAuthWebClientId,
      clientId: _iosClientId,
    );
    _initialized = true;
    debugPrint('[Google] SDK initialized');
  }

  /// 로그인 시도마다 fresh nonce로 재초기화 (iOS Google SDK ↔ Supabase 검증)
  static Future<void> _initializeWithNonce(String rawNonce) async {
    await GoogleSignIn.instance.initialize(
      serverClientId: Env.googleOAuthWebClientId,
      clientId: _iosClientId,
      nonce: rawNonce,
    );
  }

  /// Google 로그인 → Supabase Auth 세션 (세션 유지는 Supabase가 처리)
  static Future<GoogleAuthResult> signInWithSupabase() async {
    if (kIsWeb) {
      throw Exception(
        'Google 로그인은 웹에서 지원하지 않아요.\n'
        'iOS 또는 Android 시뮬레이터로 실행해주세요.',
      );
    }
    if (!isConfigured) {
      throw Exception('구글 로그인을 사용할 수 없어요.');
    }
    if (!SupabaseService.isReady) {
      throw Exception('서버 연결에 실패했어요.');
    }
    if (!_initialized) {
      await initialize();
    }

    final rawNonce = SupabaseService.client.auth.generateRawNonce();
    await _initializeWithNonce(rawNonce);

    GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw GoogleSignInCancelled();
      }
      rethrow;
    } catch (e) {
      final s = e.toString();
      if (s.contains('ApiException: 10') ||
          s.contains('DEVELOPER_ERROR') ||
          s.contains('sign_in_failed')) {
        throw Exception('구글 로그인에 실패했어요. 잠시 후 다시 시도해주세요.');
      }
      rethrow;
    }

    final email = account.email;
    if (email.isNotEmpty) {
      final status = await AuthRepository().checkOAuthLoginEmail(email, 'google');
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
          await GoogleSignIn.instance.signOut();
          throw GoogleEmailBlocked(status);
      }
    }

    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google ID 토큰이 없습니다. '
        'GOOGLE_OAUTH_WEB_CLIENT_ID(웹 Client ID)와 '
        'Supabase Google Provider Client ID가 동일한지 확인해주세요.',
      );
    }

    final authRes = await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: rawNonce,
    );
    final user = authRes.user;
    if (user == null) {
      throw Exception('Supabase 로그인에 실패했습니다.');
    }

    final photoUrl = account.photoUrl;
    final displayName = account.displayName;

    await SupabaseService.client.auth.updateUser(
      UserAttributes(
        data: {
          'auth_provider': 'google',
          if (photoUrl != null && photoUrl.isNotEmpty) 'avatar_url': photoUrl,
          if (displayName != null && displayName.isNotEmpty)
            'full_name': displayName,
        },
      ),
    );

    final refreshed = SupabaseService.client.auth.currentUser ?? user;
    return GoogleAuthResult(
      user: refreshed,
      profileImageUrl: photoUrl,
      displayName: displayName,
    );
  }

  static Future<void> signOut() async {
    if (!isConfigured || !_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[Google] signOut: $e');
    }
  }

  static Future<void> disconnect() async {
    if (!isConfigured || !_initialized) return;
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('[Google] disconnect: $e');
      rethrow;
    }
  }
}
