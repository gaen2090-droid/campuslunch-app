import 'dart:io';

import 'package:flutter/foundation.dart';

/// 첫 앱 실행 시 기기 권한 안내 (OS 권한 팝업은 확인 버튼 시점)
abstract final class AppPermissions {
  static const introTitle = '환영합니다!\n앱 이용을 위해\n아래 약관에 동의해주세요';

  static const confirmLabel = '확인';

  static const agreeAllLabel = '전체 동의합니다';

  /// Android만 주변 기기(위치 정확도 보조) 항목 표시.
  /// iOS의 「로컬 네트워크」팝업은 Flutter 디버그 연결용이라 앱에서 제어 불가.
  static List<AppPermissionCard> get permissionCards => [
        const AppPermissionCard(
          id: 'location',
          title: '위치 기반 서비스 약관 동의',
          required: true,
          documentBody:
              '위치(GPS) 권한은 필수 동의 항목입니다.\n\n'
              '지도에서 내 위치 표시, 매장 길찾기, 혼잡도 제보 시 '
              '제보 위치 검증(제보 시 GPS 좌표가 매장 인근인지 확인)에 사용됩니다.\n\n'
              '수집된 위치 정보는 제보 내역(crowd_reports)에 함께 저장되며, '
              '회원 탈퇴 시 지체 없이 삭제됩니다.\n\n'
              '위치 권한을 허용하지 않으면 지도·길찾기·혼잡도 제보 기능을 '
              '이용할 수 없습니다.',
        ),
        if (!kIsWeb && Platform.isAndroid)
          const AppPermissionCard(
            id: 'nearby_devices',
            title: '주변 기기 탐색 이용 동의',
            required: true,
            documentBody:
                '주변 기기 탐색(Wi-Fi·블루투스 스캔) 권한은 안드로이드 기기의 '
                '위치 정확도를 높이기 위해 OS가 요구하는 필수 동의 항목입니다.\n\n'
                'GPS 신호가 약한 실내 등에서도 매장 인근 여부를 더 정확히 '
                '판단할 수 있도록 주변 Wi-Fi·블루투스 신호 세기를 참고합니다.\n\n'
                '이 권한으로 블루투스 기기에 연결하거나 제어하지 않으며, '
                '수집된 신호 정보를 별도로 저장하지 않습니다.',
          ),
        const AppPermissionCard(
          id: 'notification',
          title: '마케팅 정보 앱 푸시 알림 수신 동의',
          required: false,
          subtitle: '이벤트 및 혜택 정보를 받아보실 수 있어요.',
          documentBody:
              '알림 권한은 선택 동의 항목입니다.\n\n'
              '평일 점심(12:00)·저녁(18:00)에 여유로운 매장을 안내하는 '
              '로컬 추천 알림을 보내드립니다. Firebase Analytics·FCM은 '
              '사용하지 않으며, flutter_local_notifications 기반의 '
              '기기 내 로컬 알림입니다.\n\n'
              '동의하지 않아도 앱의 다른 기능은 동일하게 이용할 수 있으며, '
              '설정 화면에서 언제든지 알림 수신 여부를 변경할 수 있습니다.',
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
    required this.id,
    required this.title,
    required this.required,
    required this.documentBody,
    this.subtitle,
  });

  final String id;
  final String title;
  final bool required;
  final String documentBody;
  final String? subtitle;
}
