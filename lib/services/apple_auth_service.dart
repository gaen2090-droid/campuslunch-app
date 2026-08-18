import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import 'google_auth_service.dart';
import 'supabase_service.dart';

class AppleAuthResult {
  final User user;
  final String? displayName;

  const AppleAuthResult({
    required this.user,
    this.displayName,
  });
}

class AppleSignInCancelled implements Exception {
  @override
  String toString() => 'Apple sign-in cancelled';
}

class AppleAuthService {
  /// 네이티브 Apple 로그인 — iOS 13+ 에서만 가능.
  /// 앱에 Apple Client ID를 넣을 필요 없음. Supabase Dashboard Apple Provider 설정이 필수.
  static Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    if (!Platform.isIOS) return false;
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Apple → Supabase Auth 세션 (세션 유지는 Supabase가 처리)
  static Future<AppleAuthResult> signInWithSupabase() async {
    if (kIsWeb) {
      throw Exception('Apple 로그인은 iOS 앱에서만 지원해요.');
    }
    if (!Platform.isIOS) {
      throw Exception('Apple 로그인은 iOS에서만 사용할 수 있어요.');
    }
    if (!SupabaseService.isReady) {
      throw Exception('서버 연결에 실패했어요.');
    }
    if (!await SignInWithApple.isAvailable()) {
      throw Exception('이 기기에서는 Apple 로그인을 사용할 수 없어요.');
    }

    final rawNonce = SupabaseService.client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AppleSignInCancelled();
      }
      rethrow;
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Apple ID 토큰이 없습니다. '
        'Apple Developer에서 Sign in with Apple을 켜고 '
        'Supabase Auth Apple Provider를 설정해주세요.',
      );
    }

    final email = credential.email;
    if (email != null && email.isNotEmpty) {
      final status = await AuthRepository().checkOAuthLoginEmail(email, 'apple');
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
          throw GoogleEmailBlocked(status);
      }
    }

    final authRes = await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    final user = authRes.user;
    if (user == null) {
      throw Exception('Supabase 로그인에 실패했습니다.');
    }

    final given = credential.givenName?.trim() ?? '';
    final family = credential.familyName?.trim() ?? '';
    final displayName = [family, given].where((s) => s.isNotEmpty).join(' ').trim();
    final fullName = displayName.isEmpty ? null : displayName;

    await SupabaseService.client.auth.updateUser(
      UserAttributes(
        data: {
          'auth_provider': 'apple',
          if (fullName != null) 'full_name': fullName,
        },
      ),
    );

    final refreshed = SupabaseService.client.auth.currentUser ?? user;
    return AppleAuthResult(user: refreshed, displayName: fullName);
  }
}
