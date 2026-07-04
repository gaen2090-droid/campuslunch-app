/// 스플래시 최소 표시 시간 (로고 디코딩·폰트 로드 여유)
const Duration kMinSplashDuration = Duration(milliseconds: 1200);

Future<void> waitMinSplashDuration(DateTime startedAt) async {
  final elapsed = DateTime.now().difference(startedAt);
  final remaining = kMinSplashDuration - elapsed;
  if (remaining > Duration.zero) {
    await Future.delayed(remaining);
  }
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
