import 'package:campus_lunch/data/crowd_status_algorithm.dart';
import 'package:flutter_test/flutter_test.dart';

CrowdStatusComputeParams _p({
  int? ownerLevel,
  List<int> users = const [],
  int? current,
  DateTime? startedAt,
  DateTime? lastUpdatedAt,
  DateTime? businessSessionStart,
  bool ownerJustReported = false,
  DateTime? now,
}) {
  return CrowdStatusComputeParams(
    ownerLevel: ownerLevel,
    userLevels20: users,
    currentDisplayLevel: current,
    statusStartedAt: startedAt,
    lastUpdatedAt: lastUpdatedAt,
    businessSessionStart: businessSessionStart,
    now: now ?? DateTime(2026, 6, 1, 12),
    ownerJustReported: ownerJustReported,
  );
}

void main() {
  group('유저 제보만', () {
    test('기존 상태 없음 + 유저 1명 자리없음 → 자리없음, low', () {
      final r = computeCrowdStatus(_p(users: [3]));
      expect(r.displayStatus, '자리없음');
      expect(r.confidence, 'low');
      expect(r.refreshUpdatedAt, isTrue);
    });

    test('기존 여유 + 유저 1명 자리없음 → 유지', () {
      final r = computeCrowdStatus(_p(users: [3], current: 1));
      expect(r.displayStatus, '여유로움');
      expect(r.refreshUpdatedAt, isFalse);
    });

    test('기존 없음 + 유저 2명 갈림 → 약간혼잡', () {
      final r = computeCrowdStatus(_p(users: [1, 3]));
      expect(r.displayStatus, '약간혼잡');
    });

    test('기존 여유 + 유저 2명 자리없음 → 약간혼잡', () {
      final r = computeCrowdStatus(_p(users: [3, 3], current: 1));
      expect(r.displayStatus, '약간혼잡');
    });

    test('기존 여유 + 유저 3명(2+1) → 약간혼잡', () {
      final r = computeCrowdStatus(_p(users: [3, 3, 2], current: 1));
      expect(r.displayStatus, '약간혼잡');
    });

    test('기존 여유 + 유저 6명(5+1) → 자리없음', () {
      final r = computeCrowdStatus(
        _p(users: [3, 3, 3, 3, 3, 2], current: 1),
      );
      expect(r.displayStatus, '자리없음');
      expect(r.confidence, 'high');
    });
  });

  group('사장님 제보만', () {
    test('사장님 여유 → 여유로움', () {
      final r = computeCrowdStatus(_p(ownerLevel: 1));
      expect(r.displayStatus, '여유로움');
    });

    test('사장님 자리없음 → 자리없음', () {
      final r = computeCrowdStatus(_p(ownerLevel: 3));
      expect(r.displayStatus, '자리없음');
    });
  });

  group('사장님 + 유저', () {
    test('같은 상태 → high', () {
      final r = computeCrowdStatus(_p(ownerLevel: 2, users: [2]));
      expect(r.displayStatus, '약간혼잡');
      expect(r.confidence, 'high');
    });

    test('사장님 여유 + 유저 1명 자리없음 → 유지', () {
      final r = computeCrowdStatus(_p(ownerLevel: 1, users: [3], current: 1));
      expect(r.displayStatus, '여유로움');
      expect(r.refreshUpdatedAt, isFalse);
    });

    test('사장님 여유 + 유저 2명 자리없음 → 유지', () {
      final r = computeCrowdStatus(_p(ownerLevel: 1, users: [3, 3], current: 1));
      expect(r.displayStatus, '여유로움');
    });

    test('사장님 여유 + 유저 4명 2:2 → 유지', () {
      final r = computeCrowdStatus(
        _p(ownerLevel: 1, users: [3, 3, 1, 1], current: 1),
      );
      expect(r.displayStatus, '여유로움');
    });

    test('사장님 여유 + 자리없음3 약간1 → 약간혼잡', () {
      final r = computeCrowdStatus(
        _p(ownerLevel: 1, users: [3, 3, 3, 2], current: 1),
      );
      expect(r.displayStatus, '약간혼잡');
      expect(r.baseSource, 'mixed');
    });

    test('사장님 여유 + 자리없음5 약간1 → 자리없음', () {
      final r = computeCrowdStatus(
        _p(ownerLevel: 1, users: [3, 3, 3, 3, 3, 2], current: 1),
      );
      expect(r.displayStatus, '자리없음');
      expect(r.baseSource, 'user');
    });

    test('사장님 자리없음 + 여유3 약간1 → 약간혼잡', () {
      final r = computeCrowdStatus(
        _p(ownerLevel: 3, users: [1, 1, 1, 2], current: 3),
      );
      expect(r.displayStatus, '약간혼잡');
    });

    test('사장님 자리없음 + 여유5 약간1 → 여유로움', () {
      final r = computeCrowdStatus(
        _p(ownerLevel: 3, users: [1, 1, 1, 1, 1, 2], current: 3),
      );
      expect(r.displayStatus, '여유로움');
    });
  });

  group('최소 유지 10분', () {
    test('약한 신호 + 10분 미만 → 유지', () {
      final r = computeCrowdStatus(
        _p(
          ownerLevel: 1,
          users: [3, 3, 3, 2],
          current: 1,
          startedAt: DateTime(2026, 6, 1, 11, 55),
        ),
      );
      expect(r.displayStatus, '여유로움');
    });

    test('강한 유저 신호 → 즉시 반영', () {
      final r = computeCrowdStatus(
        _p(
          ownerLevel: 1,
          users: [3, 3, 3, 3, 3, 2],
          current: 1,
          startedAt: DateTime(2026, 6, 1, 11, 59),
        ),
      );
      expect(r.displayStatus, '자리없음');
    });

    test('사장님 새 제보 → 즉시 반영', () {
      final r = computeCrowdStatus(
        _p(
          ownerLevel: 3,
          current: 1,
          startedAt: DateTime(2026, 6, 1, 11, 59),
          ownerJustReported: true,
        ),
      );
      expect(r.displayStatus, '자리없음');
    });
  });

  group('영업 구간 시작', () {
    test('어제 자리없음 + 새 영업 구간 → 여유로움', () {
      final r = computeCrowdStatus(
        _p(
          current: 3,
          startedAt: DateTime(2026, 5, 31, 13, 0),
          lastUpdatedAt: DateTime(2026, 5, 31, 13, 0),
          businessSessionStart: DateTime(2026, 6, 1, 11, 0),
          now: DateTime(2026, 6, 1, 12, 0),
        ),
      );
      expect(r.displayStatus, '여유로움');
      expect(r.refreshUpdatedAt, isTrue);
    });

    test('같은 영업 구간이면 기존 상태 유지', () {
      final r = computeCrowdStatus(
        _p(
          current: 3,
          startedAt: DateTime(2026, 6, 1, 11, 30),
          businessSessionStart: DateTime(2026, 6, 1, 11, 0),
          now: DateTime(2026, 6, 1, 12, 0),
        ),
      );
      expect(r.displayStatus, '자리없음');
    });

    test('점심→저녁 구간 전환 시 여유로움', () {
      final r = computeCrowdStatus(
        _p(
          current: 3,
          startedAt: DateTime(2026, 6, 1, 13, 0),
          lastUpdatedAt: DateTime(2026, 6, 1, 13, 0),
          businessSessionStart: DateTime(2026, 6, 1, 17, 0),
          now: DateTime(2026, 6, 1, 18, 0),
        ),
      );
      expect(r.displayStatus, '여유로움');
    });
  });
}
