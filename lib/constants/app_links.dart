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

  /// 친구 초대 HTTPS (폴백·메모/Safari Universal Link)
  static String inviteUrl(String referralCode) {
    final code = referralCode.trim();
    return '$baseUrl/invite?ref=${Uri.encodeQueryComponent(code)}';
  }

  /// 카카오톡 공유 버튼 → `kakao{NATIVE_KEY}://kakaolink?ref=…` 로 앱 실행용
  static Map<String, String> inviteExecutionParams(String referralCode) {
    final code = referralCode.trim();
    if (code.isEmpty) return const {};
    return {'ref': code};
  }

  /// 수신 URI → (target, restaurant linkNo, invite ref). 미지원이면 null.
  static ({AppLinkTarget target, int? linkNo, String? referralCode})? parse(
    Uri uri,
  ) {
    // 카카오톡 공유 버튼 (앱 직접 실행)
    final kakaoKey = Env.kakaoNativeAppKey;
    if (kakaoKey.isNotEmpty &&
        uri.scheme == 'kakao$kakaoKey' &&
        uri.host == 'kakaolink') {
      final ref = uri.queryParameters['ref']?.trim();
      if (ref != null && ref.isNotEmpty) {
        return (
          target: AppLinkTarget.home,
          linkNo: null,
          referralCode: ref,
        );
      }
      final r = int.tryParse(uri.queryParameters['r'] ?? '');
      if (r != null && r > 0) {
        return (
          target: AppLinkTarget.restaurant,
          linkNo: r,
          referralCode: null,
        );
      }
      return (target: AppLinkTarget.home, linkNo: null, referralCode: null);
    }

    if (!matchesHost(uri.host)) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return (target: AppLinkTarget.home, linkNo: null, referralCode: null);
    }

    switch (segments.first) {
      case 'home':
        return (target: AppLinkTarget.home, linkNo: null, referralCode: null);
      case 'invite':
        final ref = uri.queryParameters['ref']?.trim();
        return (
          target: AppLinkTarget.home,
          linkNo: null,
          referralCode: ref != null && ref.isNotEmpty ? ref : null,
        );
      case 'coupons':
        return (target: AppLinkTarget.coupons, linkNo: null, referralCode: null);
      case 'r':
      case 'restaurant':
        if (segments.length < 2) return null;
        final no = int.tryParse(segments[1]);
        if (no == null || no <= 0) return null;
        return (
          target: AppLinkTarget.restaurant,
          linkNo: no,
          referralCode: null,
        );
      default:
        return null;
    }
  }
}
