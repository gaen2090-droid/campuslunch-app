/// 브랜드 정본 에셋 경로 (런처 아이콘 = logo.png 와 동일 소스)
abstract final class BrandAssets {
  /// flutter_launcher_icons 정본 — CAM 브랜드 앱 아이콘
  static const launcherIcon = 'assets/icon/app_icon_source.png';

  /// Android 알림 small icon (tool/gen_notification_icon.dart 정본)
  static const androidNotificationIcon = '@mipmap/ic_stat_notify';

  /// 아이콘+문구 합성 (투명 배경, 폴백용)
  static const splashBrand = 'assets/images/splash_brand.png';

  /// 흰 배경+브랜드 풀스크린 — iOS/Android/Flutter 공통
  /// 갱신: python3 tool/generate_splash_brand.py
  static const splashScreenFull = 'assets/images/splash_screen_full.png';
}
