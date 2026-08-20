import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../providers/app_provider.dart';
import 'supabase_service.dart';

/// https App Link / Universal Link 수신
class AppLinkService {
  AppLinkService._();

  static final AppLinkService instance = AppLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// 카카오 SDK OAuth 복귀 — Supabase PKCE와 충돌하므로 앱 딥링크에서 제외.
  static bool isKakaoOAuthCallback(Uri uri) {
    if (uri.host != 'oauth') return false;
    final key = Env.kakaoNativeAppKey;
    if (key.isNotEmpty && uri.scheme == 'kakao$key') return true;
    return uri.scheme.startsWith('kakao');
  }

  /// 이메일 매직링크 등 Supabase auth 복귀 (campuslunch://login-callback).
  static bool isSupabaseAuthCallback(Uri uri) {
    if (isKakaoOAuthCallback(uri)) return false;
    if (uri.scheme != 'campuslunch' || uri.host != 'login-callback') {
      return false;
    }
    final fragmentParameters = Uri.splitQueryString(uri.fragment);
    bool hasParameter(String key) =>
        uri.queryParameters.containsKey(key) ||
        fragmentParameters.containsKey(key);
    return hasParameter('access_token') ||
        hasParameter('code') ||
        hasParameter('error') ||
        hasParameter('error_code') ||
        hasParameter('error_description');
  }

  Future<void> _dispatchUri(Uri uri, AppProvider provider) async {
    if (isKakaoOAuthCallback(uri)) {
      debugPrint('[AppLink] ignored Kakao OAuth callback (SDK handles it)');
      return;
    }
    if (isSupabaseAuthCallback(uri)) {
      if (!SupabaseService.isReady) return;
      debugPrint('[AppLink] Supabase auth callback: $uri');
      try {
        await SupabaseService.client.auth.getSessionFromUrl(uri);
      } on AuthException catch (e) {
        debugPrint('[AppLink] getSessionFromUrl failed: ${e.message}');
      } catch (e, st) {
        debugPrint('[AppLink] getSessionFromUrl failed: $e\n$st');
      }
      return;
    }
    provider.handleIncomingUri(uri);
  }

  Future<void> initialize(AppProvider provider) async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('[AppLink] initial: $initial');
        await _dispatchUri(initial, provider);
      }
    } catch (e, st) {
      debugPrint('[AppLink] getInitialLink failed: $e\n$st');
    }

    _sub ??= _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[AppLink] stream: $uri');
        unawaited(_dispatchUri(uri, provider));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[AppLink] stream error: $e\n$st');
      },
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
