import 'package:campus_lunch/data/crowd_status_algorithm.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 6, 1, 12, 0);

/// minutesAgo: _now 기준 몇 분 전 제보인지
LevelReport _r(int level, int minutesAgo) =>
    LevelReport(level: level, at: _now.subtract(Duration(minutes: minutesAgo)));

CrowdStatusComputeParams _p({
  LevelReport? owner,
  List<LevelReport> users = const [],
  int? current,
}) {
  return CrowdStatusComputeParams(
    ownerLatest: owner,
    userReports: users,
    currentDisplayLevel: current,
    now: _now,
  );
}

void main() {
  group('레벨 매핑', () {
    test('3단계가 서로 독립된 값으로 매핑됨', () {
      expect(crowdStatusToLevel('여유로움'), 1);
      expect(crowdStatusToLevel('약간혼잡'), 2);
      expect(crowdStatusToLevel('자리없음'), 3);
      expect(crowdLevelToStatus(1), '여유로움');
      expect(crowdLevelToStatus(2), '약간혼잡');
      expect(crowdLevelToStatus(3), '자리없음');
    });
  });

  group('대표 status는 항상 가장 최신 제보를 반영', () {
    test('유저 제보 1건 → 그 값 그대로', () {
      final r = computeCrowdStatus(_p(users: [_r(3, 1)]));
      expect(r.displayStatus, '자리없음');
    });

    test('기존 상태와 다른 유저 제보 1건 → 댐핑 없이 즉시 반영', () {
      final r = computeCrowdStatus(_p(users: [_r(3, 1)], current: 1));
      expect(r.displayStatus, '자리없음');
      expect(r.refreshUpdatedAt, isTrue);
    });

    test('유저 2건: 5분 전 자리없음, 방금 여유로움 → 대표=여유로움(최신)', () {
      final r = computeCrowdStatus(
        _p(users: [_r(3, 5), _r(1, 0)]),
      );
      expect(r.displayStatus, '여유로움');
    });

    test('유저 3건: 8분 전 여유로움, 4분 전 자리없음, 방금 약간혼잡 → 대표=약간혼잡', () {
      final r = computeCrowdStatus(
        _p(users: [_r(1, 8), _r(3, 4), _r(2, 0)]),
      );
      expect(r.displayStatus, '약간혼잡');
    });

    test('다수결과 무관하게 최신 1건이 다수와 달라도 그대로 반영', () {
      // 자리없음 5건(오래됨) + 방금 여유로움 1건 → 대표=여유로움
      final r = computeCrowdStatus(
        _p(users: [
          _r(3, 10), _r(3, 9), _r(3, 8), _r(3, 7), _r(3, 6),
          _r(1, 0),
        ]),
      );
      expect(r.displayStatus, '여유로움');
    });
  });

  group('쿨다운 없음 — 직전 상태 시작 시각과 무관하게 즉시 반영', () {
    test('방금 여유로움으로 바뀐 상태에서 자리없음 제보 → 즉시 자리없음', () {
      final r = computeCrowdStatus(_p(users: [_r(3, 0)], current: 1));
      expect(r.displayStatus, '자리없음');
    });

    test('방금 자리없음으로 바뀐 상태에서 여유로움 제보 → 즉시 여유로움', () {
      final r = computeCrowdStatus(_p(users: [_r(1, 0)], current: 3));
      expect(r.displayStatus, '여유로움');
    });
  });

  group('사장님 vs 유저 — 더 최신인 쪽이 반영', () {
    test('사장님 3분 전 여유로움(5분 이내) + 유저 1분 전 자리없음 → 사장님 우선 유지', () {
      final r = computeCrowdStatus(
        _p(owner: _r(1, 3), users: [_r(3, 1)]),
      );
      expect(r.displayStatus, '여유로움');
      expect(r.baseSource, 'owner');
    });

    test('사장님 1분 전 여유로움, 유저 5분 전 자리없음 → 여유로움', () {
      final r = computeCrowdStatus(
        _p(owner: _r(1, 1), users: [_r(3, 5)]),
      );
      expect(r.displayStatus, '여유로움');
      expect(r.baseSource, 'owner');
    });

    test('사장님만 있고 유저 제보 없음 → 사장님 값 반영', () {
      final r = computeCrowdStatus(_p(owner: _r(3, 2)));
      expect(r.displayStatus, '자리없음');
      expect(r.baseSource, 'owner');
    });

    test('사장님 6분 전(우선권 만료) + 유저 1분 전 자리없음 → 유저 반영', () {
      final r = computeCrowdStatus(
        _p(owner: _r(1, 6), users: [_r(3, 1)]),
      );
      expect(r.displayStatus, '자리없음');
      expect(r.baseSource, 'user');
    });

    test('사장님 우선권 경계(정확히 5분) → 아직 우선 적용', () {
      final r = computeCrowdStatus(
        _p(owner: _r(1, 5), users: [_r(3, 1)]),
      );
      expect(r.displayStatus, '여유로움');
      expect(r.baseSource, 'owner');
    });
  });

  group('confidence — status 결정과 무관, 다수결/최근 일치도로만 산정', () {
    test('제보가 1건뿐 → low', () {
      final r = computeCrowdStatus(_p(users: [_r(3, 1)]));
      expect(r.confidence, 'low');
      // confidence가 low여도 status는 최신 제보를 그대로 반영
      expect(r.displayStatus, '자리없음');
    });

    test('최신 제보와 직전 제보가 같은 레벨 → high', () {
      final r = computeCrowdStatus(
        _p(users: [_r(2, 1), _r(2, 0)]),
      );
      expect(r.confidence, 'high');
      expect(r.displayStatus, '약간혼잡');
    });

    test('최신 제보와 직전 제보가 크게 다름(차이 2 이상) → low', () {
      final r = computeCrowdStatus(
        _p(users: [_r(1, 1), _r(3, 0)]),
      );
      expect(r.confidence, 'low');
      expect(r.displayStatus, '자리없음');
    });

    test('의견이 완전히 갈림(동률) → low (status는 최신 그대로)', () {
      final r = computeCrowdStatus(
        _p(users: [_r(1, 1), _r(2, 0)]),
      );
      expect(r.confidence, 'low');
      expect(r.displayStatus, '약간혼잡');
    });

    test('사장님 최신과 유저 최신이 같은 레벨 → high', () {
      final r = computeCrowdStatus(
        _p(owner: _r(2, 3), users: [_r(2, 1)]),
      );
      expect(r.confidence, 'high');
    });

    test('압도적 다수(5건 이상, 80% 이상) → high', () {
      final r = computeCrowdStatus(
        _p(users: [
          _r(3, 5), _r(3, 4), _r(3, 3), _r(3, 2), _r(3, 1), _r(2, 0),
        ]),
      );
      // 최신 제보(약간혼잡)와 직전 제보(자리없음)가 다르므로 차이는 1 → high 분기까지 안 가고
      // "최신 두 개 불일치 + 차이<2" 케이스: 다수결로 판단 → high
      expect(r.confidence, 'high');
      expect(r.displayStatus, '약간혼잡');
    });
  });

  group('계산 대상 제보가 전혀 없음', () {
    test('직전 표시값 유지', () {
      final r = computeCrowdStatus(_p(current: 2));
      expect(r.displayStatus, '약간혼잡');
      expect(r.refreshUpdatedAt, isFalse);
    });

    test('직전 표시값도 없으면 기본값(여유로움)', () {
      final r = computeCrowdStatus(_p());
      expect(r.displayStatus, '여유로움');
    });
  });
}
