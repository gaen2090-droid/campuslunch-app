import 'package:flutter/material.dart';

/// 첫 앱 실행 시 기기 권한 안내 (OS 권한 팝업은 확인 버튼 시점)
abstract final class AppPermissions {
  static const introTitle = '앱 이용을 위해\n권한이 필요해요';
  static const introBody =
      '아래 권한은 캠퍼스런치 기능 제공을 위해 사용됩니다. '
      '「확인」을 누르면 기기에서 위치·주변 기기(정확도 보조)·알림 '
      '권한을 순서대로 요청해요.';

  static const confirmLabel = '확인';
  static const confirmHint =
      '확인을 누르면 위치 → 주변 기기(Android) → 알림 순으로 요청됩니다.';

  static const permissionCards = [
    AppPermissionCard(
      icon: Icons.location_on_outlined,
      title: '위치 정보',
      badge: '필수',
      body:
          '지도에서 내 위치 표시, 매장 길찾기, '
          '혼잡도 제보 시 매장 인근 여부 확인에 사용해요.',
    ),
    AppPermissionCard(
      icon: Icons.bluetooth_searching_outlined,
      title: '주변 기기 탐색 (Android)',
      badge: '필수',
      body:
          'GPS 정확도를 높이기 위해 OS가 주변 Wi-Fi·블루투스 신호를 '
          '스캔합니다. 블루투스 기기에 연결하거나 제어하지 않아요.',
    ),
    AppPermissionCard(
      icon: Icons.notifications_outlined,
      title: '알림',
      badge: '선택',
      body:
          '평일 점심(12:00)·저녁(18:00)에 '
          '여유로운 매장을 알려드릴 수 있어요. 거부해도 앱 이용은 가능해요.',
    ),
    AppPermissionCard(
      icon: Icons.analytics_outlined,
      title: '서비스 이용 기록',
      badge: '필수',
      body:
          '앱 이용·제보·배너 반응 등을 통계로 분석해 '
          '서비스 품질을 개선하는 데 사용해요. (별도 OS 권한 없음)',
    ),
  ];

  static const blockedTitle = '위치 권한이 필요해요';
  static const blockedBody =
      '혼잡도 제보와 지도 기능을 위해 위치(GPS) 권한이 '
      '필수입니다. 설정에서 「위치」를 허용한 뒤 '
      '다시 시도해주세요.';
}

class AppPermissionCard {
  const AppPermissionCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String body;
}
