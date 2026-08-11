/// 마지막 글자 받침 유무에 따라 은/는을 고른다.
/// 한글이 아니거나(영문/숫자/이모지 등) 빈 문자열이면 '는'을 기본값으로 쓴다.
String eunNeun(String word) {
  if (word.isEmpty) return '는';
  final code = word.trim().isEmpty
      ? word.codeUnitAt(word.length - 1)
      : word.trim().codeUnitAt(word.trim().length - 1);
  // 완성형 한글 음절 범위: 가(0xAC00) ~ 힣(0xD7A3)
  if (code < 0xAC00 || code > 0xD7A3) return '는';
  final hasBatchim = (code - 0xAC00) % 28 != 0;
  return hasBatchim ? '은' : '는';
}
