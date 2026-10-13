import 'package:campus_lunch/models/restaurant.dart';
import 'package:campus_lunch/utils/available_restaurant_ranking.dart';
import 'package:campus_lunch/utils/restaurant_sort.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 13, 12, 0);

Restaurant _r(
  String name, {
  String source = 'user',
  required int minutesAgo,
  String status = '여유로움',
  int? seatCount,
}) =>
    Restaurant(
      id: name,
      name: name,
      category: 'x',
      area: 'x',
      address: 'x',
      status: status,
      updated: minutesAgo,
      imageUrl: '',
      distance: 0,
      x: 0,
      y: 0,
      hours: '',
      reports: const {},
      menu: const [],
    ).copyWith(
      hasCrowdUpdate: true,
      updatedAt: _now.subtract(Duration(minutes: minutesAgo)),
      crowdBaseSource: source,
      ownerSeatCount: seatCount,
    );

List<String> _names(List<Restaurant> l) => l.map((r) => r.name).toList();

// buildAvailableSection 은 DateTime.now() 기준이라 실제 현재 시각 기준으로 만든다.
Restaurant _live(String name, {String source = 'user', required int minutesAgo}) {
  final at = DateTime.now().subtract(Duration(minutes: minutesAgo));
  return Restaurant(
    id: name,
    name: name,
    category: 'x',
    area: 'x',
    address: 'x',
    status: '여유로움',
    updated: minutesAgo,
    imageUrl: '',
    distance: 0,
    x: 0,
    y: 0,
    hours: '',
    reports: const {},
    menu: const [],
  ).copyWith(hasCrowdUpdate: true, updatedAt: at, crowdBaseSource: source);
}

void main() {
  group('추천 배너(buildAvailableSection)', () {
    test('5분 이내 사장님 제보가 더 오래됐어도 유저 제보보다 우선', () {
      final section = buildAvailableSection([
        _live('user1', minutesAgo: 1),
        _live('owner4', source: 'owner', minutesAgo: 4),
      ], true);
      expect(section.recommended?.name, 'owner4');
    });

    test('사장님 제보가 5분을 넘으면 기존대로 최신 유저 제보', () {
      final section = buildAvailableSection([
        _live('user1', minutesAgo: 1),
        _live('owner7', source: 'owner', minutesAgo: 7),
      ], true);
      expect(section.recommended?.name, 'user1');
    });

    test('5분 이내 사장님 제보가 여럿이면 가장 최신', () {
      final section = buildAvailableSection([
        _live('owner3', source: 'owner', minutesAgo: 3),
        _live('owner1', source: 'owner', minutesAgo: 1),
        _live('user0', minutesAgo: 0),
      ], true);
      expect(section.recommended?.name, 'owner1');
    });
  });

  group('prioritizeFreshOwnerReports', () {
    test('5분 이내 사장님 제보는 최상단, 그 안에서 최신순', () {
      final list = [
        _r('user1', minutesAgo: 1),
        _r('owner4', source: 'owner', minutesAgo: 4),
        _r('user2', minutesAgo: 2),
        _r('owner2', source: 'owner', minutesAgo: 2),
      ];
      expect(
        _names(prioritizeFreshOwnerReports(list, _now)),
        ['owner2', 'owner4', 'user1', 'user2'],
      );
    });

    test('5분 초과 사장님 제보는 올리지 않고 기존 순서 유지', () {
      final list = [
        _r('user1', minutesAgo: 1),
        _r('owner6', source: 'owner', minutesAgo: 6),
      ];
      expect(
        _names(prioritizeFreshOwnerReports(list, _now)),
        ['user1', 'owner6'],
      );
    });

    test('정확히 5분은 포함', () {
      final list = [
        _r('user1', minutesAgo: 1),
        _r('owner5', source: 'owner', minutesAgo: 5),
      ];
      expect(
        _names(prioritizeFreshOwnerReports(list, _now)),
        ['owner5', 'user1'],
      );
    });

    test('좌석 입력으로 가정된 상태(owner_seat)도 사장님 제보로 취급', () {
      final list = [
        _r('user1', minutesAgo: 1),
        _r('seat', source: 'owner_seat', minutesAgo: 3, seatCount: 5),
      ];
      expect(
        _names(prioritizeFreshOwnerReports(list, _now)),
        ['seat', 'user1'],
      );
    });

    test('좌석 입력 이후 상태가 달라졌으면(isSeatDerived=false) 올리지 않음', () {
      final list = [
        _r('user1', minutesAgo: 1),
        // 5명이면 여유로움이 정상인데 약간혼잡이면 다른 제보로 바뀐 것
        _r('seatChanged',
            source: 'owner_seat', minutesAgo: 3, seatCount: 5, status: '약간혼잡'),
      ];
      expect(
        _names(prioritizeFreshOwnerReports(list, _now)),
        ['user1', 'seatChanged'],
      );
    });

    test('사장님 제보가 없으면 원본 순서 그대로', () {
      final list = [_r('a', minutesAgo: 3), _r('b', minutesAgo: 1)];
      expect(_names(prioritizeFreshOwnerReports(list, _now)), ['a', 'b']);
    });

    test('나머지는 입력 순서(기존 정렬)를 보존', () {
      final list = [
        _r('c', minutesAgo: 9),
        _r('owner', source: 'owner', minutesAgo: 1),
        _r('a', minutesAgo: 3),
        _r('b', minutesAgo: 1),
      ];
      expect(
        _names(prioritizeFreshOwnerReports(list, _now)),
        ['owner', 'c', 'a', 'b'],
      );
    });
  });
}
