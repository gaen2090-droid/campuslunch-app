import '../config/env.dart';

/// App Link / Universal Link 경로 (https://{host}/…)
enum AppLinkTarget {
  home,
  coupons,
  restaurant,
}

class AppLinks {
  AppLinks._();

  static String get host => Env.appLinkHost;

  static String get baseUrl => 'https://$host';

  static bool matchesHost(String? linkHost) {
    if (linkHost == null || linkHost.isEmpty) return false;
    final h = host.toLowerCase();
    final incoming = linkHost.toLowerCase();
    return incoming == h || incoming == 'www.$h';
  }

  static String homeUrl() => '$baseUrl/home';

  static String couponsUrl() => '$baseUrl/coupons';

  static String restaurantUrl(int linkNo) => '$baseUrl/r/$linkNo';

  /// 수신 URI → (target, restaurant linkNo). host 불일치·미지원 경로면 null.
  static ({AppLinkTarget target, int? linkNo})? parse(Uri uri) {
    if (!matchesHost(uri.host)) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return (target: AppLinkTarget.home, linkNo: null);
    }

    switch (segments.first) {
      case 'home':
        return (target: AppLinkTarget.home, linkNo: null);
      case 'coupons':
        return (target: AppLinkTarget.coupons, linkNo: null);
      case 'r':
      case 'restaurant':
        if (segments.length < 2) return null;
        final no = int.tryParse(segments[1]);
        if (no == null || no <= 0) return null;
        return (target: AppLinkTarget.restaurant, linkNo: no);
      default:
        return null;
    }
  }
}
