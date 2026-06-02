import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// 이메일 인증 링크 → 앱 딥링크(`campuslunch://login-callback`) 세션 복구
class AuthDeepLinkHandler {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static Future<void> init() async {
    if (!SupabaseService.isReady) return;

    Future<void> handleUri(Uri? uri) async {
      if (uri == null) return;
      if (!_isAuthCallback(uri)) return;
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        debugPrint('[Auth] deep link session restored: $uri');
      } catch (e, st) {
        debugPrint('[Auth] getSessionFromUrl failed: $e\n$st');
      }
    }

    try {
      final initial = await _appLinks.getInitialLink();
      await handleUri(initial);
    } catch (e) {
      debugPrint('[Auth] getInitialLink: $e');
    }

    await _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      handleUri,
      onError: (e) => debugPrint('[Auth] uriLinkStream: $e'),
    );
  }

  static bool _isAuthCallback(Uri uri) {
    if (uri.scheme == 'campuslunch' && uri.host == 'login-callback') {
      return true;
    }
    // Supabase가 https 콜백으로 열 때
    return uri.fragment.contains('access_token') ||
        uri.queryParameters.containsKey('code');
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
