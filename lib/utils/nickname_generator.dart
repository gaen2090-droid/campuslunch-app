/// 회원가입 시 기본 닉네임 (앙대 + 과일 + 숫자 4자리)
String generateNickname() {
  const fruits = ['딸기', '사고', '포도', '수박', '레몬', '망고', '복숭아', '바나나'];
  final idx = DateTime.now().millisecondsSinceEpoch % fruits.length;
  final num = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
  return '앙대${fruits[idx]}$num';
}

bool isPlaceholderNickname(String? nickname) {
  if (nickname == null || nickname.trim().isEmpty) return true;
  return nickname == '사용자' || nickname == '카카오 사용자';
}

/// [isTaken] 이 true 면 재시도. RPC 미배포(null)면 최대 시도 후 마지막 후보 반환.
Future<String> generateAvailableNickname(
  Future<bool?> Function(String nickname) isTaken, {
  int maxAttempts = 15,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    final candidate = generateNickname();
    final taken = await isTaken(candidate);
    if (taken == false) return candidate;
    if (taken == null) return candidate;
  }
  return '앙대${DateTime.now().millisecondsSinceEpoch % 100000}';
}
