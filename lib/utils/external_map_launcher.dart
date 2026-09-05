import 'package:url_launcher/url_launcher.dart';

import '../models/map_lat_lng.dart';

enum ExternalMapApp { kakaoMap, naverMap }

extension ExternalMapAppLabel on ExternalMapApp {
  String get label => switch (this) {
        ExternalMapApp.kakaoMap => '카카오맵',
        ExternalMapApp.naverMap => '네이버 지도',
      };
}

/// 카카오맵/네이버 지도 앱으로 도보 길찾기를 넘기는 딥링크.
/// 각 앱이 설치되어 있지 않으면 스토어(웹) 링크로 폴백한다.
abstract final class ExternalMapLauncher {
  static Future<bool> openWalkingRoute({
    required ExternalMapApp app,
    required MapLatLng origin,
    required MapLatLng destination,
    required String destinationName,
  }) async {
    final name = Uri.encodeComponent(destinationName);
    final Uri appUri;
    final Uri fallbackUri;

    switch (app) {
      case ExternalMapApp.kakaoMap:
        appUri = Uri.parse(
          'kakaomap://route?sp=${origin.latitude},${origin.longitude}'
          '&ep=${destination.latitude},${destination.longitude}'
          '&by=FOOT',
        );
        fallbackUri = Uri.parse(
          'https://map.kakao.com/link/to/$name,${destination.latitude},${destination.longitude}',
        );
        break;
      case ExternalMapApp.naverMap:
        appUri = Uri.parse(
          'nmap://route/walk?slat=${origin.latitude}&slng=${origin.longitude}'
          '&dlat=${destination.latitude}&dlng=${destination.longitude}'
          '&dname=$name&appname=com.campuslunch.app',
        );
        fallbackUri = Uri.parse(
          'https://map.naver.com/p/directions/'
          '${origin.longitude},${origin.latitude},내 위치'
          '/${destination.longitude},${destination.latitude},$name'
          '/-/walk',
        );
        break;
    }

    if (await canLaunchUrl(appUri)) {
      return launchUrl(appUri, mode: LaunchMode.externalApplication);
    }
    return launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
  }
}
