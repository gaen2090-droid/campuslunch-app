import 'package:flutter/foundation.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../config/env.dart';

/// 카카오맵 SDK — 앱 첫 화면 이후 백그라운드 초기화 (스플래시 지연 방지)
class KakaoMapBootstrap {
  static Future<void>? _initFuture;
  static bool initFailed = false;

  static Future<void> ensureInitialized() {
    if (Env.kakaoMapSdkInitialized || kIsWeb || !Env.hasKakaoNativeKey) {
      return Future<void>.value();
    }
    _initFuture ??= _run();
    return _initFuture!;
  }

  static Future<void> _run() async {
    try {
      await KakaoMapsFlutter.init(Env.kakaoNativeAppKey);
      Env.kakaoMapSdkInitialized = true;
      initFailed = false;
    } catch (e, st) {
      initFailed = true;
      debugPrint('[KakaoMap] deferred init failed: $e\n$st');
    }
  }
}
