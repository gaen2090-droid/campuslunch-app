import 'package:campus_lunch/models/restaurant.dart';
import 'package:campus_lunch/utils/restaurant_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Restaurant _r({required String status, required int updated}) => Restaurant(
      id: 'x',
      name: 'x',
      category: 'x',
      area: 'x',
      address: 'x',
      status: status,
      updated: updated,
      imageUrl: '',
      distance: 0,
      x: 0,
      y: 0,
      hours: '',
      reports: const {},
      menu: const [],
    );

void main() {
  group('availableLatestGroup (여유로움/약간혼잡)', () {
    test('여유로움 15분 → group 0', () {
      expect(availableLatestGroup(_r(status: '여유로움', updated: 15)), 0);
    });
    test('여유로움 16분 → group 1', () {
      expect(availableLatestGroup(_r(status: '여유로움', updated: 16)), 1);
    });
    test('여유로움 30분 → group 1', () {
      expect(availableLatestGroup(_r(status: '여유로움', updated: 30)), 1);
    });
    test('여유로움 31분 → group 4', () {
      expect(availableLatestGroup(_r(status: '여유로움', updated: 31)), 4);
    });
    test('약간혼잡 15분 → group 2', () {
      expect(availableLatestGroup(_r(status: '약간혼잡', updated: 15)), 2);
    });
    test('약간혼잡 16분 → group 3', () {
      expect(availableLatestGroup(_r(status: '약간혼잡', updated: 16)), 3);
    });
    test('약간혼잡 30분 → group 3', () {
      expect(availableLatestGroup(_r(status: '약간혼잡', updated: 30)), 3);
    });
    test('약간혼잡 31분 → group 5', () {
      expect(availableLatestGroup(_r(status: '약간혼잡', updated: 31)), 5);
    });
    test('순서: 여유15 < 여유30 < 약간15 < 약간30 < 여유31 < 약간31', () {
      final groups = [
        availableLatestGroup(_r(status: '여유로움', updated: 15)),
        availableLatestGroup(_r(status: '여유로움', updated: 30)),
        availableLatestGroup(_r(status: '약간혼잡', updated: 15)),
        availableLatestGroup(_r(status: '약간혼잡', updated: 30)),
        availableLatestGroup(_r(status: '여유로움', updated: 31)),
        availableLatestGroup(_r(status: '약간혼잡', updated: 31)),
      ];
      for (var i = 0; i < groups.length - 1; i++) {
        expect(groups[i], lessThan(groups[i + 1]));
      }
    });
  });

  group('busyLatestGroup (자리없음)', () {
    test('15분 → group 0', () {
      expect(busyLatestGroup(_r(status: '자리없음', updated: 15)), 0);
    });
    test('16분 → group 1', () {
      expect(busyLatestGroup(_r(status: '자리없음', updated: 16)), 1);
    });
    test('30분 → group 1', () {
      expect(busyLatestGroup(_r(status: '자리없음', updated: 30)), 1);
    });
    test('31분 → group 2', () {
      expect(busyLatestGroup(_r(status: '자리없음', updated: 31)), 2);
    });
    test('순서: 15 < 30 < 31', () {
      final groups = [
        busyLatestGroup(_r(status: '자리없음', updated: 15)),
        busyLatestGroup(_r(status: '자리없음', updated: 30)),
        busyLatestGroup(_r(status: '자리없음', updated: 31)),
      ];
      for (var i = 0; i < groups.length - 1; i++) {
        expect(groups[i], lessThan(groups[i + 1]));
      }
    });
  });

  group('여유로운순 status priority', () {
    test('여유로움이 약간혼잡보다 우선', () {
      expect(availableSortStatusPriority('여유로움'),
          lessThan(availableSortStatusPriority('약간혼잡')));
    });
  });
}
