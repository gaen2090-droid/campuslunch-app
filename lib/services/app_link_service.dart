import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../providers/app_provider.dart';

/// https App Link / Universal Link 수신
class AppLinkService {
  AppLinkService._();

  static final AppLinkService instance = AppLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  Future<void> initialize(AppProvider provider) async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('[AppLink] initial: $initial');
        provider.handleIncomingUri(initial);
      }
    } catch (e, st) {
      debugPrint('[AppLink] getInitialLink failed: $e\n$st');
    }

    _sub ??= _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[AppLink] stream: $uri');
        provider.handleIncomingUri(uri);
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
