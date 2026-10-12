import 'package:campus_lunch/models/owner_seat_update.dart';
import 'package:campus_lunch/models/restaurant.dart';
import 'package:campus_lunch/utils/owner_seat_signal.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 14, 12, 0);

Restaurant _r({
  String status = '여유로움',
  bool hasCrowdUpdate = false,
  DateTime? updatedAt,
  bool crowdEnabled = true,
}) =>
    Restaurant(
      id: 'r1',
      name: 'r1',
      category: '한식',
      area: '정문',
      address: '정문',
      status: status,
      updated: 0,
      imageUrl: '',
      distance: 0,
      latitude: 37.5,
      longitude: 126.95,
      x: 0,
      y: 0,
      hours: '11:00 - 21:00',
      reports: const {},
      menu: const [],
      hasCrowdUpdate: hasCrowdUpdate,
      updatedAt: updatedAt,
      crowdEnabled: crowdEnabled,
    );

OwnerSeatUpdate _seat(int seats, {int minutesAgo = 5}) => OwnerSeatUpdate(
      availableSeats: seats,
      createdAt: _now.subtract(Duration(minutes: minutesAgo)),
    );

void main() {
  group('좌석 → 상태 가정', () {
    test('0명=자리없음, 1~3명=약간혼잡, 4명 이상=여유로움', () {
      expect(ownerSeatImpliedStatus(0), '자리없음');
      expect(ownerSeatImpliedStatus(1), '약간혼잡');
      expect(ownerSeatImpliedStatus(3), '약간혼잡');
      expect(ownerSeatImpliedStatus(4), '여유로움');
      expect(ownerSeatImpliedStatus(12), '여유로움');
    });
  });

  group('applyOwnerSeatSignal', () {
    test('제보가 없으면 좌석으로 상태를 정하고 사장님 입력으로 표시', () {
      final r = applyOwnerSeatSignal(_r(), _seat(4), _now);
      expect(r.status, '여유로움');
      expect(r.hasCrowdUpdate, isTrue);
      expect(r.crowdBaseSource, 'owner_seat');
      expect(r.ownerSeatCount, 4);
      expect(r.seatBadgeLabel, '4명가능');
      expect(r.updatedAt, _seat(4).createdAt);
    });

    test('3명은 약간혼잡, 0명은 자리없음(입장 어려움)', () {
      final three = applyOwnerSeatSignal(_r(), _seat(3), _now);
      expect(three.status, '약간혼잡');
      expect(three.seatBadgeLabel, '3명가능');
      final zero = applyOwnerSeatSignal(_r(), _seat(0), _now);
      expect(zero.status, '자리없음');
      expect(zero.seatBadgeLabel, '입장 어려움');
    });

    test('더 최신 제보가 있으면 제보가 우선', () {
      final base = _r(
        status: '약간혼잡',
        hasCrowdUpdate: true,
        updatedAt: _now.subtract(const Duration(minutes: 2)),
      );
      final r = applyOwnerSeatSignal(base, _seat(6, minutesAgo: 5), _now);
      expect(r.status, '약간혼잡');
      expect(r.crowdBaseSource, isNot('owner_seat'));
      expect(r.seatBadgeLabel, isNull);
    });

    test('좌석 입력이 더 최신이면 좌석이 우선', () {
      final base = _r(
        status: '약간혼잡',
        hasCrowdUpdate: true,
        updatedAt: _now.subtract(const Duration(minutes: 10)),
      );
      final r = applyOwnerSeatSignal(base, _seat(6, minutesAgo: 5), _now);
      expect(r.status, '여유로움');
      expect(r.seatBadgeLabel, '6명가능');
    });

    test('30분이 지난 좌석 입력은 무시', () {
      final r = applyOwnerSeatSignal(_r(), _seat(6, minutesAgo: 31), _now);
      expect(r.hasCrowdUpdate, isFalse);
      expect(r.seatBadgeLabel, isNull);
    });

    test('영업안함·컬렉션 전용 매장은 건드리지 않는다', () {
      final closed = applyOwnerSeatSignal(_r(status: '영업안함'), _seat(6), _now);
      expect(closed.status, '영업안함');
      final col = applyOwnerSeatSignal(_r(crowdEnabled: false), _seat(6), _now);
      expect(col.hasCrowdUpdate, isFalse);
    });

    test('다른 제보로 상태가 바뀌면 좌석 문구는 더 이상 쓰지 않는다', () {
      final seated = applyOwnerSeatSignal(_r(), _seat(6), _now);
      final changed = seated.copyWith(status: '자리없음');
      expect(changed.seatBadgeLabel, isNull);
    });
  });
}
