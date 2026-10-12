import '../models/owner_seat_update.dart';
import '../models/restaurant.dart';

/// 사장님 좌석 입력이 혼잡도 신호로 인정되는 시간. 혼잡도 뱃지 노출 기준(30분)과 맞춘다.
const Duration ownerSeatSignalWindow = Duration(minutes: 30);

/// crowd 제보가 없거나 좌석 입력보다 오래됐을 때, 사장님의 좌석 입력을 혼잡도 상태로
/// 가정해 매장에 반영한다 (0명=자리없음, 1~3명=약간혼잡, 4명 이상=여유로움).
///
/// - 같은 시각 이후의 제보/사장님 상태 입력이 있으면 그쪽이 우선이다(최신 우선).
/// - 영업안함이거나 제보를 받지 않는 컬렉션 전용 매장은 건드리지 않는다.
/// - 반영된 매장은 crowdBaseSource='owner_seat', ownerSeatCount 가 채워진다.
Restaurant applyOwnerSeatSignal(
  Restaurant r,
  OwnerSeatUpdate? seat,
  DateTime now,
) {
  if (seat == null) return r;
  if (!r.crowdEnabled || r.status == '영업안함') return r;
  if (now.difference(seat.createdAt) > ownerSeatSignalWindow) return r;

  final at = r.updatedAt;
  if (r.hasCrowdUpdate && at != null && !at.isBefore(seat.createdAt)) {
    return r;
  }

  final minutes = now.difference(seat.createdAt).inMinutes;
  return r.copyWith(
    status: ownerSeatImpliedStatus(seat.availableSeats),
    updated: minutes < 0 ? 0 : minutes,
    hasCrowdUpdate: true,
    updatedAt: seat.createdAt,
    crowdBaseSource: 'owner_seat',
    ownerSeatCount: seat.availableSeats,
  );
}
