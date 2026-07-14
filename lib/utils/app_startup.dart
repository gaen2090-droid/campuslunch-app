import 'package:flutter/services.dart';

import '../constants/brand_assets.dart';

/// 스플래시 최소 표시 시간 (네이티브→Flutter 전환 여유)
const Duration kMinSplashDuration = Duration(milliseconds: 1800);

Future<void> waitMinSplashDuration(DateTime startedAt) async {
  final elapsed = DateTime.now().difference(startedAt);
  final remaining = kMinSplashDuration - elapsed;
  if (remaining > Duration.zero) {
    await Future.delayed(remaining);
  }
}

/// runApp 이전에 호출 — 스플래시 첫 프레임에서 이미지 스왑 방지
Future<void> preloadSplashResources() async {
  await rootBundle.load(BrandAssets.splashScreenFull);
}

/// 권한 안내 완료 후에만 실행 (카카오맵·푸시 등 — OS 권한 팝업 선행 방지)
Future<void> Function()? runDeferredStartupOnce;
bool _deferredStartupDone = false;

Future<void> triggerDeferredStartup() async {
  if (_deferredStartupDone) return;
  final fn = runDeferredStartupOnce;
  if (fn == null) return;
  _deferredStartupDone = true;
  await fn();
}
