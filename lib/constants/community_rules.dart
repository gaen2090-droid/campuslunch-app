/// 커뮤니티 이용규칙 (글쓰기 화면 요약·전문 링크)
abstract final class CommunityRules {
  static const policyTitle = '커뮤니티 이용방침';
  static const policyAssetPath = 'assets/legal/COMMUNITY_POLICY.md';

  static const introLead =
      '캠퍼스런치는 누구나 기분 좋게 참여할 수 있는 커뮤니티를 만들기 위해 '
      '커뮤니티 이용규칙을 제정하여 운영하고 있습니다. '
      '위반 시 게시물이 삭제되고 서비스 이용이 일정 기간 제한될 수 있습니다.';

  static const introSummary =
      '아래는 자유 게시판에 해당하는 핵심 내용에 대한 요약 사항이며, '
      '게시물 작성 전 커뮤니티 이용규칙 전문을 반드시 확인하시기 바랍니다.';

  static const viewAllLabel = '커뮤니티 이용규칙 전체 보기';

  /// 자유 게시판 글쓰기 화면에 표시하는 요약 규정 (에브리타임 구조 참고, 캠퍼스런치 맞춤)
  static const summarySections = <CommunityRuleSection>[
    CommunityRuleSection(
      heading: '※ 욕설·비방·혐오 표현 금지',
      bullets: [
        '욕설, 폭언, 비속어, 음란·선정적 표현을 사용하는 행위',
        '특정인·매장·단체를 비방하거나 조롱·괴롭히는 행위',
        '성별, 종교, 출신, 지역, 직업 등을 이유로 차별·혐오를 조장하는 행위',
        '위 내용을 은유·비유·줄임말로 표현하는 행위',
      ],
    ),
    CommunityRuleSection(
      heading: '※ 홍보·판매·스팸 금지',
      bullets: [
        '영리 여부와 관계없이 업체·개인을 홍보하거나 판매·모집을 유도하는 행위',
        '바이럴 마케팅, 제휴·리뷰 대가 요구, 무단 광고 링크·연락처 게시',
        '동일·유사 내용 반복 게시(도배) 및 의미 없는 스팸',
      ],
      footnote:
          '앱에 등록된 매장 1곳 연결은 맛집 후기 목적에 한해 허용됩니다. '
          '무관한 상업 홍보는 금지됩니다.',
    ),
    CommunityRuleSection(
      heading: '※ 정치·사회 논쟁 유발 게시 금지',
      bullets: [
        '국가기관, 정치·사회 단체, 언론 등을 언급하며 논쟁을 유발하는 행위',
        '정책·외교·이념, 사회 갈등 이슈에 대한 주장·선동을 게시하는 행위',
        '맛집·캠퍼스 생활과 무관한 정치·사회 이슈 토론',
      ],
      footnote: '자유 게시판은 식당·점심·캠퍼스 생활 관련 소통 공간입니다.',
    ),
    CommunityRuleSection(
      heading: '※ 개인정보·불법 콘텐츠 유통 금지',
      bullets: [
        '본인·타인의 연락처, 계정, 사진 등 개인정보를 동의 없이 노출하는 행위',
        '불법 촬영물, 음란물, 폭력·자해 조장 콘텐츠 게시·유통',
        '저작권·초상권을 침해하는 무단 도용·재배포',
      ],
      footnote:
          '불법 촬영물 등 법령 위반 콘텐츠는 관련 법령에 따라 신고·차단될 수 있습니다.',
    ),
    CommunityRuleSection(
      heading: '※ 허위 정보·부정 이용 금지',
      bullets: [
        '확인되지 않은 매장 정보·혼잡도를 허위로 유포하는 행위',
        '타인·매장에 대한 악의적 허위 사실 적시',
        '금칙어 필터 우회, 신고·제재 회피, 스탬프·리워드 부정 획득 시도',
      ],
    ),
  ];
}

class CommunityRuleSection {
  const CommunityRuleSection({
    required this.heading,
    required this.bullets,
    this.footnote,
  });

  final String heading;
  final List<String> bullets;
  final String? footnote;
}
