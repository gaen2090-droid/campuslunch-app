/// 앱 내 약관·정책 전문 (assets/legal/*.md)
abstract final class LegalTerms {
  static const title = '서비스 이용 동의';
  static const intro =
      '회원가입을 마치기 전에 아래 약관·정책을 확인하고 '
      '필수 항목에 동의해주세요.';

  static const agreeAllLabel = '전체 동의합니다';
  static const confirmLabel = '동의하고 시작하기';
  static const contactEmail = 'campuslunch2026@gmail.com';

  static const checkItems = [
    LegalTermsCheckItem(
      id: 'age_over_14',
      label: '만 14세 이상입니다',
      required: true,
      assetPath: null,
    ),
    LegalTermsCheckItem(
      id: 'privacy',
      label: '개인정보 처리방침',
      required: true,
      assetPath: 'assets/legal/PRIVACY_POLICY.md',
    ),
    LegalTermsCheckItem(
      id: 'terms',
      label: '이용약관',
      required: true,
      assetPath: 'assets/legal/TERMS_OF_SERVICE.md',
    ),
    LegalTermsCheckItem(
      id: 'operation',
      label: '제보 운영정책',
      required: true,
      assetPath: 'assets/legal/REPORT_OPERATION_POLICY.md',
    ),
    LegalTermsCheckItem(
      id: 'reward',
      label: '리워드 지급 정책',
      required: true,
      assetPath: 'assets/legal/REWARD_POLICY.md',
    ),
    LegalTermsCheckItem(
      id: 'marketing_consent',
      label: '개인정보 활용 및 마케팅 정보 수신',
      required: false,
      assetPath: null,
    ),
  ];

  static LegalTermsCheckItem? itemById(String id) {
    for (final item in checkItems) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class LegalTermsCheckItem {
  const LegalTermsCheckItem({
    required this.id,
    required this.label,
    required this.required,
    required this.assetPath,
  });

  final String id;
  final String label;
  final bool required;
  final String? assetPath;
}

bool isRequiredLegalTermsGranted(Map<String, bool> agreed) =>
    LegalTerms.checkItems
        .where((item) => item.required)
        .every((item) => agreed[item.id] == true);
