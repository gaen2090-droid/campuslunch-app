import 'dart:math';

import 'package:campus_lunch/models/restaurant.dart';
import 'package:campus_lunch/utils/lunch_fairy_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-14 수요일 12:00 — 평일 점심, 영업시간 11:00-21:00 안.
final _now = DateTime(2026, 10, 14, 12, 0);
const _campus = FairyPosition(37.50699, 126.95707);

/// 위도 0.0009° ≈ 100m.
double _lat(double meters) => 37.50699 + meters / 100 * 0.0009;

Restaurant _r(
  String id, {
  String category = '한식',
  String status = '제보필요',
  int? freshMinutes,
  bool crowdEnabled = true,
  List<MenuItem> menu = const [],
  List<String> signatures = const [],
  bool solo = false,
  bool date = false,
  double meters = 200,
  String hours = '11:00 - 21:00',
  int popularity = 0,
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
    latitude: _lat(meters),
    longitude: 126.95707,
    x: 0,
    y: 0,
    hours: hours,
    reports: const {},
    menu: menu,
    hasCrowdUpdate: hasUpdate,
    updatedAt: hasUpdate ? _now.subtract(Duration(minutes: freshMinutes)) : null,
    crowdEnabled: crowdEnabled,
    soloFriendly: solo,
    dateFriendly: date,
    signatureMenus: signatures,
    popularityScore: popularity,
  );
}

const _lunch = [
  MenuItem(name: '공기밥', price: 1000),
  MenuItem(name: '제육덮밥', price: 8000),
];

FairyOutcome _run(
  List<Restaurant> list, {
  FairyRequest request = const FairyRequest(),
  FairyPosition? position,
  Set<String> seen = const {},
  int seed = 1,
}) =>
    fairyRecommend(list, request,
        now: _now, position: position, seenIds: seen, random: Random(seed));

void main() {
  group('신선 제보 풀', () {
    test('15분 이내 여유로움 제보가 있으면 제보 없는 매장보다 항상 우선', () {
      final list = [
        _r('fresh', status: '여유로움', freshMinutes: 10, menu: _lunch, meters: 600),
        for (var i = 0; i < 5; i++) _r('none$i', menu: _lunch, meters: 50),
      ];
      for (var seed = 0; seed < 30; seed++) {
        final pick = _run(list, seed: seed).pick!;
        expect(pick.restaurant.id, 'fresh', reason: 'seed=$seed');
        expect(pick.reason, FairyReason.freshRelaxed);
        expect(pick.freshMinutes, 10);
      }
    });

    test('30분 지난 여유로움은 신선하지 않아 중립 취급 (혼잡도로 순위를 가르지 않음)', () {
      final list = [
        _r('stale', status: '여유로움', freshMinutes: 30, meters: 700),
        _r('near', meters: 50),
      ];
      final seen = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final pick = _run(list, seed: seed, position: _campus).pick!;
        expect(pick.reason, isNot(FairyReason.freshRelaxed));
        seen.add(pick.restaurant.id);
      }
      // 신선 풀이 없으므로 가까운 곳이 점수상 앞서고, 오래된 제보 때문에 일방적으로 밀리지 않는다.
      expect(seen, contains('near'));
    });

    test('hasCrowdUpdate=false 인 매장의 기본 status(여유로움)는 신선으로 보지 않음', () {
      final noReport = _r('noReport', status: '여유로움', meters: 100);
      expect(isFairyFresh(noReport, _now), isFalse);
    });

    test('약간혼잡 신선 제보는 freshModerate 이유', () {
      final pick = _run([_r('a', status: '약간혼잡', freshMinutes: 5)]).pick!;
      expect(pick.reason, FairyReason.freshModerate);
    });
  });

  group('자리없음 제외', () {
    test('14분 전 자리없음은 제외, 16분 전은 후보로 남는다', () {
      final out14 = _run([_r('full', status: '자리없음', freshMinutes: 14)]);
      expect(out14.pick, isNull);
      expect(out14.nothingOpen, isTrue);

      final out16 = _run([_r('full', status: '자리없음', freshMinutes: 16)]);
      expect(out16.pick?.restaurant.id, 'full');
    });

    test('조건을 풀어도 자리없음 제외는 풀리지 않는다', () {
      final list = [_r('full', status: '자리없음', freshMinutes: 3, category: '분식')];
      final out = _run(list, request: const FairyRequest(cuisine: '분식', budgetLimit: 8000));
      expect(out.pick, isNull);
    });
  });

  group('후보 필터', () {
    test('카페와 마감 30분 이내 매장은 제외', () {
      final list = [
        _r('cafe', category: '카페'),
        _r('closing', hours: '11:00 - 12:20'),
        _r('ok'),
      ];
      expect(_run(list).pick!.restaurant.id, 'ok');
    });

    test('이미 본 매장은 다시 나오지 않고, 다 보면 pick=null/nothingOpen=false', () {
      final list = [_r('a'), _r('b')];
      final out = _run(list, seen: {'a', 'b'});
      expect(out.pick, isNull);
      expect(out.nothingOpen, isFalse);
    });

    test('영업 중인 후보가 아예 없으면 nothingOpen', () {
      final out = _run([_r('closed', hours: '17:00 - 22:00')]);
      expect(out.nothingOpen, isTrue);
    });
  });

  group('컬렉션 전용 폴백', () {
    test('제보 대상 후보가 없으면 컬렉션 전용 매장 추천', () {
      final list = [_r('col', crowdEnabled: false, category: '일식')];
      final pick = _run(list, request: const FairyRequest(cuisine: '일식')).pick!;
      expect(pick.tier, FairyTier.collectionOnly);
      expect(pick.relaxed, isEmpty);
    });

    test('혼밥 표시가 있어도 제보 대상 후보가 남아 있으면 컬렉션 전용은 나오지 않는다', () {
      final list = [
        _r('rep'),
        _r('col', crowdEnabled: false, solo: true, date: true),
      ];
      for (final c in FairyCompanion.values) {
        for (var seed = 0; seed < 50; seed++) {
          expect(
            _run(list, request: FairyRequest(companion: c), seed: seed)
                .pick!
                .restaurant
                .id,
            'rep',
          );
        }
      }
    });

    test('제보 대상을 모두 본 뒤에는 표시 있는 컬렉션 전용이 먼저 나온다', () {
      final list = [
        _r('rep'),
        _r('plain', crowdEnabled: false),
        _r('solo', crowdEnabled: false, solo: true),
      ];
      var solo = 0;
      for (var seed = 0; seed < 100; seed++) {
        final pick = _run(list, seen: {'rep'}, seed: seed).pick!;
        expect(pick.tier, FairyTier.collectionOnly);
        if (pick.restaurant.id == 'solo') solo++;
      }
      expect(solo, greaterThan(50));
    });

    test('제보 대상 후보가 있으면 컬렉션 전용은 쓰지 않는다', () {
      final list = [_r('rep'), _r('col', crowdEnabled: false)];
      for (var seed = 0; seed < 10; seed++) {
        expect(_run(list, seed: seed).pick!.restaurant.id, 'rep');
      }
    });

    test('조건을 풀기 전에 컬렉션 전용을 먼저 시도한다', () {
      final list = [
        _r('rep', category: '한식'),
        _r('col', crowdEnabled: false, category: '일식'),
      ];
      final pick = _run(list, request: const FairyRequest(cuisine: '일식')).pick!;
      expect(pick.restaurant.id, 'col');
      expect(pick.relaxed, isEmpty);
    });
  });

  group('조건 완화', () {
    test('예산 → 음식종류 순으로 풀고 풀린 항목을 기록', () {
      final list = [
        _r('korean',
            category: '한식', menu: const [MenuItem(name: '코스', price: 20000)]),
      ];
      final pick = _run(list,
              request: const FairyRequest(cuisine: '분식', budgetLimit: 8000))
          .pick!;
      expect(pick.relaxed, [FairyRelax.budget, FairyRelax.cuisine]);
    });

    test('거리는 마지막에 푼다', () {
      final list = [_r('far', category: '한식', meters: 900)];
      final pick = _run(list,
              request: const FairyRequest(cuisine: '분식', walkMinutes: 5),
              position: _campus)
          .pick!;
      expect(pick.relaxed, [FairyRelax.cuisine, FairyRelax.distance]);
    });

    test('도보 5분(350m) 이내면 거리 조건을 풀지 않는다', () {
      final list = [_r('near', meters: 300), _r('far', meters: 900)];
      final pick = _run(list,
              request: const FairyRequest(walkMinutes: 5), position: _campus)
          .pick!;
      expect(pick.restaurant.id, 'near');
      expect(pick.relaxed, isEmpty);
      expect(pick.walkMinutes, 4); // 300m / 70m/분
    });
  });

  group('예산', () {
    test('공기밥 같은 사이드(4천원 미만)로는 예산을 통과하지 못한다', () {
      final list = [
        _r('steak', menu: const [
          MenuItem(name: '공기밥', price: 1000),
          MenuItem(name: '스테이크', price: 15000),
        ]),
      ];
      final pick = _run(list, request: const FairyRequest(budgetLimit: 8000)).pick!;
      expect(pick.relaxed, [FairyRelax.budget]);
    });

    test('가격 0원(미확인)·메뉴 없음은 예산 필터를 통과', () {
      final list = [
        _r('zero', menu: const [MenuItem(name: '돈까스', price: 0)]),
      ];
      final pick = _run(list, request: const FairyRequest(budgetLimit: 8000)).pick!;
      expect(pick.relaxed, isEmpty);
      expect(pick.menu?.price, 0);
    });

    test('대표메뉴 가격이 예산 판정 기준', () {
      final r = _r('sig',
          signatures: const ['제육덮밥'],
          menu: const [
            MenuItem(name: '된장찌개', price: 5000),
            MenuItem(name: '제육덮밥', price: 9000),
          ]);
      expect(fairyBudgetPrice(r), 9000);
      expect(fairyPickMenu(r, 8000)?.name, '제육덮밥');
    });

    test('대표메뉴가 메뉴 목록에 없으면(사장님이 이름 변경) 지정 안 된 것으로 취급', () {
      final r = _r('renamed',
          signatures: const ['옛이름'],
          menu: const [
            MenuItem(name: '된장찌개', price: 5000),
            MenuItem(name: '제육덮밥', price: 9000),
          ]);
      expect(fairySignatureMenus(r), isEmpty);
      // 4천원 이상 중 예산 안에서 가장 비싼 메뉴
      expect(fairyPickMenu(r, 8000)?.name, '된장찌개');
      expect(fairyBudgetPrice(r), 5000);
    });
  });

  group('대표메뉴 2개', () {
    final two = _r('two', signatures: const ['제육덮밥', '돈까스'], menu: const [
      MenuItem(name: '제육덮밥', price: 9000),
      MenuItem(name: '돈까스', price: 7000),
      MenuItem(name: '우동', price: 6000),
    ]);

    test('유효한 대표메뉴는 최대 2개, 목록에 없는 이름은 무시', () {
      expect(fairySignatureMenus(two).map((m) => m.name), ['제육덮밥', '돈까스']);
      final partial = _r('p',
          signatures: const ['제육덮밥', '없는메뉴'],
          menu: const [MenuItem(name: '제육덮밥', price: 9000)]);
      expect(fairySignatureMenus(partial).map((m) => m.name), ['제육덮밥']);
    });

    test('예산 판정은 대표메뉴 중 가장 싼 가격', () {
      expect(fairyBudgetPrice(two), 7000);
      final pick = _run([two], request: const FairyRequest(budgetLimit: 8000)).pick!;
      expect(pick.relaxed, isEmpty); // 돈까스(7천)가 예산 안
    });

    test('대표메뉴 중 하나가 가격 미확인(0원)이면 예산 필터를 통과', () {
      final mixed = _r('mixed', signatures: const ['제육덮밥', '돈까스'], menu: const [
        MenuItem(name: '제육덮밥', price: 9000),
        MenuItem(name: '돈까스', price: 0),
      ]);
      expect(fairyBudgetPrice(mixed), isNull);
      final pick =
          _run([mixed], request: const FairyRequest(budgetLimit: 8000)).pick!;
      expect(pick.relaxed, isEmpty);
      expect(pick.menu?.name, '돈까스'); // 0원 = 예산 안으로 간주
    });

    test('대표메뉴가 모두 예산 밖이면 후보에서 빠지고 예산 조건이 풀린다', () {
      final pricey = _r('pricey', signatures: const ['스테이크', '파스타'], menu: const [
        MenuItem(name: '스테이크', price: 15000),
        MenuItem(name: '파스타', price: 12000),
      ]);
      final pick =
          _run([pricey], request: const FairyRequest(budgetLimit: 8000)).pick!;
      expect(pick.relaxed, [FairyRelax.budget]);
    });

    test('예산 안의 대표메뉴만 추천 메뉴로 나온다', () {
      for (var seed = 0; seed < 20; seed++) {
        final m = fairyPickMenu(two, 8000, Random(seed))!;
        expect(m.name, '돈까스');
      }
    });

    test('예산이 없으면 두 대표메뉴가 모두 나올 수 있다', () {
      final names = <String>{
        for (var seed = 0; seed < 40; seed++)
          fairyPickMenu(two, null, Random(seed))!.name,
      };
      expect(names, {'제육덮밥', '돈까스'});
    });
  });

  group('혼밥/친구랑', () {
    test('혼밥이면 혼밥 표시 매장이 이유로 노출', () {
      final pick = _run([_r('solo', solo: true)]).pick!;
      expect(pick.reason, FairyReason.soloFriendly);
    });

    test('친구랑이면 혼밥 표시를 이유로 쓰지 않는다', () {
      final pick = _run([_r('solo', solo: true)],
              request: const FairyRequest(companion: FairyCompanion.friend))
          .pick!;
      expect(pick.reason, FairyReason.general);
    });

    test('친구랑이면 혼밥 표시 매장은 후순위지만 후보에서 빠지지는 않는다', () {
      const req = FairyRequest(companion: FairyCompanion.friend);
      for (var seed = 1; seed <= 20; seed++) {
        final pick = _run(
          [_r('solo', solo: true), _r('plain')],
          request: req,
          seed: seed,
        ).pick!;
        expect(pick.reason, isNot(FairyReason.soloFriendly));
      }
      // 혼밥 표시 매장뿐이면 그곳이라도 추천한다.
      expect(_run([_r('solo', solo: true)], request: req).pick!.restaurant.id,
          'solo');
    });

    test('친구랑이면 일반 매장이 혼밥 표시 매장보다 더 자주 추천된다', () {
      const req = FairyRequest(companion: FairyCompanion.friend);
      var plain = 0;
      var solo = 0;
      for (var seed = 1; seed <= 200; seed++) {
        final id = _run([_r('solo', solo: true), _r('plain')],
                request: req, seed: seed)
            .pick!
            .restaurant
            .id;
        id == 'plain' ? plain++ : solo++;
      }
      expect(plain, greaterThan(solo));
    });

    test('밥약이면 밥약 표시 매장이 이유로 노출', () {
      final pick = _run([_r('date', date: true)],
              request: const FairyRequest(companion: FairyCompanion.date))
          .pick!;
      expect(pick.reason, FairyReason.dateFriendly);
    });

    test('밥약이면 밥약 표시 매장이 혼밥 표시 매장보다 우선', () {
      for (var seed = 1; seed <= 20; seed++) {
        final pick = _run(
          [_r('solo', solo: true), _r('date', date: true)],
          request: const FairyRequest(companion: FairyCompanion.date),
          seed: seed,
        ).pick!;
        expect(pick.reason, isNot(FairyReason.soloFriendly));
      }
    });

    test('혼밥이면 밥약 표시를 이유로 쓰지 않는다', () {
      final pick = _run([_r('date', date: true)]).pick!;
      expect(pick.reason, FairyReason.general);
    });
  });

  group('혼잡도 뱃지', () {
    test('30분 이내 제보만 뱃지 경과 분을 돌려준다', () {
      expect(fairyCrowdBadgeMinutes(_r('a', status: '여유로움', freshMinutes: 0), _now), 0);
      expect(fairyCrowdBadgeMinutes(_r('a', status: '여유로움', freshMinutes: 12), _now), 12);
      expect(fairyCrowdBadgeMinutes(_r('a', status: '약간혼잡', freshMinutes: 30), _now), 30);
    });

    test('30분을 넘긴 제보와 제보 없음은 뱃지를 띄우지 않는다', () {
      expect(fairyCrowdBadgeMinutes(_r('a', status: '여유로움', freshMinutes: 31), _now), isNull);
      expect(fairyCrowdBadgeMinutes(_r('a', status: '여유로움', freshMinutes: 120), _now), isNull);
      expect(fairyCrowdBadgeMinutes(_r('a', status: '여유로움'), _now), isNull);
    });
  });

  group('모델/배너', () {
    test('copyWith는 혼밥·대표메뉴 필드를 유지한다 (거리 갱신 시 사라지면 안 됨)', () {
      final r = _r('a', solo: true, signatures: const ['제육덮밥', '된장찌개']);
      final c = r.copyWith(distance: 123, status: '여유로움');
      expect(c.soloFriendly, isTrue);
      expect(c.signatureMenus, ['제육덮밥', '된장찌개']);
    });

    test('배너는 평일 11:00~14:00에만', () {
      expect(isFairyBannerTime(DateTime(2026, 10, 14, 11, 0)), isTrue);
      expect(isFairyBannerTime(DateTime(2026, 10, 14, 13, 59)), isTrue);
      expect(isFairyBannerTime(DateTime(2026, 10, 14, 14, 0)), isFalse);
      expect(isFairyBannerTime(DateTime(2026, 10, 14, 10, 59)), isFalse);
      expect(isFairyBannerTime(DateTime(2026, 10, 17, 12, 0)), isFalse); // 토요일
    });
  });
}
