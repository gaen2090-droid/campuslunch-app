import 'dart:math';

import 'package:campus_lunch/models/restaurant.dart';
import 'package:campus_lunch/utils/lunch_roulette.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-14 수요일 12:00 — 평일 점심, 영업시간 11:00-21:00 안.
final _now = DateTime(2026, 10, 14, 12, 0);

Restaurant _r(
  String id, {
  String category = '한식',
  String status = '제보필요',
  int? freshMinutes,
  bool crowdEnabled = true,
  String hours = '11:00 - 21:00',
}) {
  final hasUpdate = freshMinutes != null;
  return Restaurant(
    id: id,
    name: id,
    category: category,
    area: '정문',
    address: '정문',
    status: status,
    updated: freshMinutes ?? 0,
    imageUrl: '',
    distance: 200,
    latitude: 37.50699,
    longitude: 126.95707,
    x: 0,
    y: 0,
    hours: hours,
    reports: const {},
    menu: const [],
    hasCrowdUpdate: hasUpdate,
    updatedAt:
        hasUpdate ? _now.subtract(Duration(minutes: freshMinutes)) : null,
    crowdEnabled: crowdEnabled,
  );
}

List<Restaurant> _many(String category, int n, {String prefix = ''}) =>
    [for (var i = 0; i < n; i++) _r('$prefix$category$i', category: category)];

RouletteDeal _deal(
  List<Restaurant> list, {
  Set<String> cuisines = const {},
  bool mixIn = false,
  Set<String> exclude = const {},
  int seed = 1,
}) =>
    dealRoulette(list,
        now: _now,
        cuisines: cuisines,
        mixIn: mixIn,
        excludeIds: exclude,
        random: Random(seed));

void main() {
  group('입장가능 최대 4곳 포함', () {
    test('15분 이내 여유로움 제보 매장은 최대 4곳만 우선 들어간다', () {
      final fresh = [
        for (var i = 0; i < 6; i++)
          _r('fresh$i', status: '여유로움', freshMinutes: 5),
      ];
      final list = [...fresh, ..._many('한식', 10)];
      for (var seed = 0; seed < 20; seed++) {
        final deal = _deal(list, seed: seed);
        expect(deal.slots.length, 8);
        final n = deal.slots.where((r) => isFreshRelaxed(r, _now)).length;
        expect(n, 4);
      }
    });

    test('약간혼잡 제보는 입장가능 우선 칸에 포함하지 않는다', () {
      final list = [
        for (var i = 0; i < 5; i++)
          _r('busy$i', status: '약간혼잡', freshMinutes: 5),
        ..._many('한식', 10),
      ];
      expect(isFreshRelaxed(list.first, _now), isFalse);
      // 우선 슬롯이 없으므로 busy 매장이 일반 후보로만 섞인다 (보장 없음).
      final deal = _deal(list);
      expect(deal.slots.length, 8);
    });

    test('15분이 지난 여유로움 제보는 입장가능으로 보지 않는다', () {
      final stale = _r('stale', status: '여유로움', freshMinutes: 20);
      expect(isFreshRelaxed(stale, _now), isFalse);
    });

    test('입장가능 매장이 4곳 미만이면 있는 만큼만 들어간다', () {
      final list = [
        _r('f0', status: '여유로움', freshMinutes: 3),
        _r('f1', status: '여유로움', freshMinutes: 3),
        ..._many('한식', 12),
      ];
      for (var seed = 0; seed < 10; seed++) {
        final deal = _deal(list, seed: seed);
        final ids = deal.slots.map((r) => r.id).toSet();
        expect(ids.contains('f0'), isTrue);
        expect(ids.contains('f1'), isTrue);
      }
    });
  });

  group('음식 종류 분포', () {
    test('종류를 고르지 않으면 8칸이 종류별로 골고루 퍼진다', () {
      final list = [
        ..._many('한식', 10),
        ..._many('중식', 10),
        ..._many('일식', 10),
        ..._many('양식', 10),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final deal = _deal(list, seed: seed);
        final byCat = <String, int>{};
        for (final r in deal.slots) {
          byCat[r.category] = (byCat[r.category] ?? 0) + 1;
        }
        expect(byCat.length, 4);
        expect(byCat.values.every((c) => c == 2), isTrue);
      }
    });

    test('한 종류가 압도적으로 많아도 다른 종류가 밀려나지 않는다', () {
      final list = [..._many('한식', 30), ..._many('분식', 2), ..._many('일식', 2)];
      final deal = _deal(list);
      final cats = deal.slots.map((r) => r.category).toSet();
      expect(cats, containsAll(['한식', '분식', '일식']));
    });

    test('종류를 복수 선택하면 선택한 종류만 나온다', () {
      final list = [..._many('한식', 10), ..._many('분식', 5), ..._many('일식', 5)];
      final deal = _deal(list, cuisines: {'분식', '일식'});
      expect(deal.slots.every((r) => r.category != '한식'), isTrue);
      expect(deal.slots.length, 8);
    });
  });

  group('매장 수 부족', () {
    test('3~7곳이면 있는 만큼 칸을 만들고 안내를 띄운다', () {
      final list = [..._many('분식', 4), ..._many('한식', 10)];
      final deal = _deal(list, cuisines: {'분식'});
      expect(deal.slots.length, 4);
      expect(deal.shortage, RouletteShortage.fewer);
      expect(deal.canSpin, isTrue);
      expect(rouletteNotice(deal, {'분식'}), contains('4곳뿐'));
    });

    test('2곳 이하면 돌리기를 막는다', () {
      final list = [..._many('분식', 2), ..._many('한식', 10)];
      final deal = _deal(list, cuisines: {'분식'});
      expect(deal.shortage, RouletteShortage.blocked);
      expect(deal.canSpin, isFalse);
      expect(deal.slots, isEmpty);
      expect(deal.poolSize, 2);
    });

    test('0곳이면 매장이 없다고 안내한다', () {
      final deal = _deal(_many('한식', 10), cuisines: {'아시아'});
      expect(deal.shortage, RouletteShortage.blocked);
      expect(rouletteNotice(deal, {'아시아'}), contains('없어요'));
    });

    test('다른 음식도 섞으면 선택한 종류를 먼저 넣고 나머지를 채운다', () {
      final list = [..._many('분식', 1), ..._many('한식', 6), ..._many('일식', 6)];
      final deal = _deal(list, cuisines: {'분식'}, mixIn: true);
      expect(deal.slots.length, 8);
      expect(deal.mixedIn, isTrue);
      expect(deal.slots.any((r) => r.category == '분식'), isTrue);
      expect(deal.selectedCount, 1);
      expect(rouletteNotice(deal, {'분식'}), contains('다른 음식'));
    });

    test('복수 선택 안내 문구는 종류를 모두 보여준다', () {
      final list = [..._many('분식', 1), ..._many('아시아', 1)];
      final deal = _deal(list, cuisines: {'분식', '아시아'});
      expect(rouletteNotice(deal, {'분식', '아시아'}), contains('분식·아시아'));
    });
  });

  group('후보 자격', () {
    test('카페·영업 전·15분 내 자리없음 매장은 칸에 들어가지 않는다', () {
      final list = [
        _r('cafe', category: '카페'),
        _r('closed', hours: '17:00 - 22:00'),
        _r('full', status: '자리없음', freshMinutes: 5),
        ..._many('한식', 8),
      ];
      final deal = _deal(list);
      final ids = deal.slots.map((r) => r.id);
      expect(ids, isNot(contains('cafe')));
      expect(ids, isNot(contains('closed')));
      expect(ids, isNot(contains('full')));
    });

    test('컬렉션 전용 매장은 제보 대상 매장이 남아 있으면 들어가지 않는다', () {
      final list = [
        ..._many('한식', 5),
        _r('coll', crowdEnabled: false),
      ];
      final deal = _deal(list);
      expect(deal.slots.map((r) => r.id), isNot(contains('coll')));
    });

    test('제외 목록의 매장은 빠진다', () {
      final list = _many('한식', 9);
      final deal = _deal(list, exclude: {'한식0'});
      expect(deal.slots.map((r) => r.id), isNot(contains('한식0')));
    });
  });

  group('후보 바꾸기', () {
    test('새로 뽑을 매장이 모자라도 칸 수는 8칸을 유지한다', () {
      final list = [..._many('한식', 6), ..._many('일식', 5)]; // 총 11곳
      final first = _deal(list);
      final avoid = first.slots.map((r) => r.id).toSet();
      final second =
          dealRoulette(list, now: _now, avoidIds: avoid, random: Random(5));
      expect(second.slots.length, 8);
      // 피할 수 있는 3곳은 모두 새로 들어간다.
      final fresh = second.slots.where((r) => !avoid.contains(r.id)).length;
      expect(fresh, 3);
    });

    test('새 후보가 충분하면 이전 후보는 하나도 들어가지 않는다', () {
      final list = _many('한식', 20);
      final first = _deal(list);
      final avoid = first.slots.map((r) => r.id).toSet();
      final second =
          dealRoulette(list, now: _now, avoidIds: avoid, random: Random(9));
      expect(second.slots.every((r) => !avoid.contains(r.id)), isTrue);
    });
  });

  test('멈추는 칸은 칸 수 안에서 고르게 나온다', () {
    final rng = Random(7);
    final counts = List.filled(8, 0);
    for (var i = 0; i < 8000; i++) {
      counts[rouletteWinnerIndex(8, rng)]++;
    }
    for (final c in counts) {
      expect(c, inInclusiveRange(800, 1200));
    }
  });
}
