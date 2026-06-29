/// 스플래시 최소 표시 시간 (브랜딩용, 이전 2초 고정 대기 제거)
const Duration kMinSplashDuration = Duration(milliseconds: 450);

Future<void> waitMinSplashDuration(DateTime startedAt) async {
  final elapsed = DateTime.now().difference(startedAt);
  final remaining = kMinSplashDuration - elapsed;
  if (remaining > Duration.zero) {
    await Future.delayed(remaining);
  }
}
