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

/// 카드의 주 문구. 예) "3명 입장 가능해요", "지금은 입장이 어려워요".
String ownerSeatCardHeadline(OwnerSeatUpdate update) {
  if (update.availableSeats == 0) return '지금은 입장이 어려워요';
  return '${update.availableSeats}명 입장 가능해요';
}

/// 카드의 보조 문구. 예) "사장님 · 5분 전".
String ownerSeatCardMeta(OwnerSeatUpdate update, {DateTime? now}) =>
    '사장님 · ${formatOwnerSeatAge(update.createdAt, now: now)}';

String ownerSeatCardLine(OwnerSeatUpdate update, {DateTime? now}) =>
    '${ownerSeatCardHeadline(update)} · ${ownerSeatCardMeta(update, now: now)}';
