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

/// 닉네임 전용 금칙어(욕설 + 사칭·브랜드 도용 방지).
/// 앱 부팅 시 서버 목록(`nickname_banned_words`)으로 교체 시도하며,
/// 실패하거나 아직 로드 전이면 이 기본 목록으로 계속 동작한다(빈 필터 방지).
List<String> _nicknameBannedWords = [
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
  '캠퍼스런치',
  '캠런',
  '운영자',
  '관리자',
  '캠런관리자',
  '캠런운영자',
  '캠퍼스런치관리자',
  '캠퍼스런치운영자',
  'admin',
  'administrator',
  'operator',
];

void setNicknameBannedWords(List<String> words) {
  if (words.isEmpty) return;
  _nicknameBannedWords = words;
}

bool containsReservedNicknameWord(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  return _nicknameBannedWords.any((w) => normalized.contains(w.toLowerCase()));
}

/// 닉네임에 사용할 수 없는 표현(욕설 + 사칭성 예약어)이 포함되어 있으면 true.
bool containsForbiddenNicknameWord(String text) {
  return containsReservedNicknameWord(text);
}
