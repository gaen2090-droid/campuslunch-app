import '../models/owner_seat_update.dart';

String formatOwnerSeatAge(DateTime createdAt, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final diff = at.difference(createdAt);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  return '${diff.inMinutes}분 전';
}

String ownerSeatMessage(OwnerSeatUpdate update) {
  if (update.availableSeats == 0) {
    return '지금은 바로 입장이 어려워요.';
  }
  return '${update.availableSeats}명 입장 가능해요!';
}

String ownerSeatCardLine(OwnerSeatUpdate update, {DateTime? now}) {
  final age = formatOwnerSeatAge(update.createdAt, now: now);
  if (update.availableSeats == 0) {
    return '입장 가능 인원: 바로 입장 어려움 ($age) (사장님 입력)';
  }
  return '입장 가능 인원: ${update.availableSeats}명 ($age) (사장님 입력)';
}
