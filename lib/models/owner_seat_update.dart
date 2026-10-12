/// 사장님이 입력한 입장 가능 인원을 혼잡도 상태로 가정하는 규칙.
/// 0명 = 자리없음, 1~3명 = 약간혼잡, 4명 이상 = 여유로움.
String ownerSeatImpliedStatus(int availableSeats) {
  if (availableSeats <= 0) return '자리없음';
  if (availableSeats <= 3) return '약간혼잡';
  return '여유로움';
}

class OwnerSeatUpdate {
  final int availableSeats;
  final DateTime createdAt;

  const OwnerSeatUpdate({
    required this.availableSeats,
    required this.createdAt,
  });

  factory OwnerSeatUpdate.fromMap(Map<String, dynamic> map) {
    return OwnerSeatUpdate(
      availableSeats: (map['available_seats'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  bool isVisibleAt(DateTime now) =>
      now.difference(createdAt) < const Duration(hours: 1);
}
