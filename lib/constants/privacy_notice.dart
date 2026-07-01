import 'package:flutter/material.dart';

/// 앱 권한·개인정보 수집 안내 (배포·동의 화면 공통)
abstract final class PrivacyNotice {
  static const serviceName = '캠퍼스런치';

  static const permissionsSummary = [
    PrivacyPermissionItem(
      icon: Icons.location_on_outlined,
      title: '위치 정보 (필수)',
      required: true,
      body:
          '지도에서 내 위치 표시, 매장까지 길찾기, 혼잡도 제보 시 '
          '매장 인근 여부 확인에 사용합니다. '
          '본 서비스의 핵심 기능 제공을 위해 필수적으로 수집·이용됩니다.',
    ),
    PrivacyPermissionItem(
      icon: Icons.notifications_outlined,
      title: '알림 (선택)',
      required: false,
      body:
          '평일 점심(12:00)·저녁(18:00)에 여유로운 매장 추천 등 '
          '서비스 안내 알림을 보내기 위해 사용합니다. '
          '거부하셔도 앱 이용에는 제한이 없습니다.',
    ),
    PrivacyPermissionItem(
      icon: Icons.analytics_outlined,
      title: '서비스 이용 기록 (필수)',
      required: true,
      body:
          '앱 실행·화면 조회, 배너·푸시 반응, 혼잡도 제보 등 '
          '서비스 이용 과정에서 생성되는 기록을 수집합니다. '
          '이 정보는 통계·지표로 가공되어 서비스 품질 개선, '
          '기능 개선, 오류 분석 목적으로만 이용됩니다.',
    ),
  ];

  /// 동의 체크리스트 (전체 동의 · 항목별)
  static const consentCheckItems = [
    PrivacyConsentCheckItem(
      id: 'location',
      label: '위치 정보(GPS) 수집·이용',
      required: true,
    ),
    PrivacyConsentCheckItem(
      id: 'analytics',
      label: '서비스 이용 기록 수집·이용',
      required: true,
    ),
    PrivacyConsentCheckItem(
      id: 'privacy',
      label: '개인정보 수집·이용',
      required: true,
    ),
    PrivacyConsentCheckItem(
      id: 'notification',
      label: '알림 수신',
      required: false,
    ),
  ];

  static const collectionTitle = '개인정보 수집·이용 안내';

  static const collectionIntro =
      '$serviceName(이하 "회사")는 「개인정보 보호법」 등 관련 법령을 준수하며, '
      '아래와 같이 개인정보를 수집·이용합니다.';

  static const collectionItems = [
    PrivacyCollectionItem(
      category: '회원 가입·로그인',
      items: '이메일, 닉네임, 소셜 로그인 식별정보(카카오·Google 제공 시)',
      purpose: '회원 식별, 계정 관리, 고객 문의 대응',
      retention: '회원 탈퇴 시 지체 없이 파기 (관련 법령에 따른 보관 예외 제외)',
      required: true,
    ),
    PrivacyCollectionItem(
      category: '혼잡도 제보·리워드',
      items: '제보 내역, 스탬프·기프티콘 이용 기록, 닉네임(제보 표시용)',
      purpose: '혼잡도 정보 제공, 리워드 운영, 부정 이용 방지',
      retention: '회원 탈퇴 시 지체 없이 파기',
      required: true,
    ),
    PrivacyCollectionItem(
      category: '위치 정보',
      items: '기기 GPS 좌표 (제보·지도·길찾기 이용 시)',
      purpose: '매장 인근 제보 확인, 지도·길찾기 기능 제공, 혼잡도 서비스 운영',
      retention:
          '제보·이용 목적 달성 후 즉시 파기, 서버에는 좌표가 포함된 제보 메타데이터로 저장될 수 있음',
      required: true,
    ),
    PrivacyCollectionItem(
      category: '서비스 이용 분석',
      items:
          '앱 실행 기록, 화면·배너·푸시 반응, 기기 OS 정보, '
          '앱 버전, 이용 일시 (개인을 직접 식별하지 않는 형태의 통계 포함)',
      purpose:
          '이용자 행태 분석, 서비스·기능 품질 개선, '
          '접속 빈도·이용 통계 산출, 맞춤형 서비스 제공',
      retention: '수집일로부터 1년 (통계 목적 달성 후 파기 또는 익명화)',
      required: true,
    ),
    PrivacyCollectionItem(
      category: '고객 피드백',
      items: '피드백 내용, 카테고리, 작성 일시',
      purpose: '서비스 개선, 불편 사항 처리',
      retention: '처리 완료 후 1년',
      required: false,
    ),
  ];

  static const rightsNotice =
      '귀하는 개인정보 수집·이용에 대한 동의를 거부할 권리가 있습니다. '
      '다만, 필수 항목(위치 정보·서비스 이용 기록 등)에 대한 동의를 '
      '거부하실 경우 회원 가입 및 서비스 이용이 제한될 수 있습니다.\n\n'
      '선택 항목(알림)은 기기 설정 또는 앱 내 설정에서 '
      '언제든지 변경·철회할 수 있습니다.\n\n'
      '개인정보 열람·정정·삭제·처리정지 요청은 앱 내 '
      '「문의·피드백」 또는 운영자 이메일을 통해 요청하실 수 있습니다.';

  static const agreeAllLabel = '전체 동의합니다';

  static const consentButtonLabel = '확인하고 계속하기';
}

class PrivacyPermissionItem {
  const PrivacyPermissionItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.required,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool required;
}

class PrivacyConsentCheckItem {
  const PrivacyConsentCheckItem({
    required this.id,
    required this.label,
    required this.required,
  });

  final String id;
  final String label;
  final bool required;
}

class PrivacyCollectionItem {
  const PrivacyCollectionItem({
    required this.category,
    required this.items,
    required this.purpose,
    required this.retention,
    required this.required,
  });

  final String category;
  final String items;
  final String purpose;
  final String retention;
  final bool required;
}
