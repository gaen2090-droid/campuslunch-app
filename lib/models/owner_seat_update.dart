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
