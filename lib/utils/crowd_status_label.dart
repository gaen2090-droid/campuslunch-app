String formatUpdateAge(int minutes) {
  if (minutes <= 0) return '방금 전';
  if (minutes < 60) return '$minutes분 전';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours시간 전';
  final days = hours ~/ 24;
  return '$days일 전';
}

/// 화면 표시: `여유로움` 또는 `여유로움 · 5분 전`
String formatCrowdStatusLine(
  String status, {
  required int updatedMinutes,
  bool hasCrowdUpdate = true,
}) {
  if (status == '영업안함') return status;
  if (!hasCrowdUpdate) return status;
  return '$status · ${formatUpdateAge(updatedMinutes)}';
}
