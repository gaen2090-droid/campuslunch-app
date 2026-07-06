/// 커뮤니티 이용 정책 위반 표현 즉시 차단(UX용, 1차 방어).
/// 완벽 탐지가 아니라 즉시 피드백용 — 실질 백본은 신고→관리자 삭제.
///
/// 앱 부팅 시 서버 목록(`community_banned_words`)으로 교체 시도하며,
/// 실패하거나 아직 로드 전이면 이 기본 목록으로 계속 동작한다(빈 필터 방지).
List<String> _bannedWords = [
  '씨발',
  '시발',
  '병신',
  '개새끼',
  '새끼',
  '지랄',
  '좆',
  '창녀',
  '걸레',
  '느금',
  '니미',
  '엠창',
  '보지',
  '자지',
  'ㅅㅂ',
  'ㅂㅅ',
  'ㅈㄹ',
];

void setBannedWords(List<String> words) {
  if (words.isEmpty) return;
  _bannedWords = words;
}

bool containsProfanity(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  return _bannedWords.any((w) => normalized.contains(w));
}
