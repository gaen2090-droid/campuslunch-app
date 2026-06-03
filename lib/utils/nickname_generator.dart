/// 회원가입 시 기본 닉네임 (앙대 + 과일 + 숫자 4자리)
String generateNickname() {
  const fruits = ['딸기', '사과', '포도', '수박', '레몬', '망고', '복숭아', '바나나'];
  final idx = DateTime.now().millisecondsSinceEpoch % fruits.length;
  final num = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
  return '앙대${fruits[idx]}$num';
}

bool isPlaceholderNickname(String? nickname) {
  if (nickname == null || nickname.trim().isEmpty) return true;
  return nickname == '사용자' || nickname == '카카오 사용자';
}
