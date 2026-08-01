String formatUpdateAge(int minutes) {
  if (minutes <= 0) return '방금 전';
  if (minutes < 60) return '$minutes분 전';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours시간 전';
  final days = hours ~/ 24;
  return '$days일 전';
}

/// DateTime 기준으로 실시간 계산 — fetch 시점 고정값인 `updated`(int)와 달리 항상 정확함
String formatUpdateAgeFromDateTime(DateTime? updatedAt) {
  if (updatedAt == null) return '방금 전';
  return formatUpdateAge(DateTime.now().difference(updatedAt).inMinutes.clamp(0, 99999));
}

/// 하루(24시간) 이상 지난 제보는 몇 시에 있었는지 알기 어려워지므로
/// "9일 전 · 11:45"처럼 시각을 함께 보여준다.
String formatUpdateAgeWithTime(DateTime createdAt) {
  final minutes = DateTime.now().difference(createdAt).inMinutes.clamp(0, 99999);
  final age = formatUpdateAge(minutes);
  if (minutes < 24 * 60) return age;
  final hh = createdAt.hour.toString().padLeft(2, '0');
  final mm = createdAt.minute.toString().padLeft(2, '0');
  return '$age · $hh:$mm';
}

/// 화면 표시: `여유로움` 또는 `여유로움 · 5분 전`
String formatCrowdStatusLine(
  String status, {
  required int updatedMinutes,
  bool hasCrowdUpdate = true,
}) {
  if (status == '영업안함') return status;
  if (!hasCrowdUpdate) return '제보없음';
  return '$status · ${formatUpdateAge(updatedMinutes)}';
}
