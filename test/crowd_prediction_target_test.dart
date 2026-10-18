import 'package:campus_lunch/models/crowd_prediction.dart';
import 'package:campus_lunch/models/restaurant.dart';
import 'package:campus_lunch/utils/crowd_prediction_target.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-19 는 월요일, 10-17 은 토요일.
DateTime _mon(int h, int m) => DateTime(2026, 10, 19, h, m);

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

void main() {
  group('노출 시간 (평일 11:30~13:00)', () {
    test('11:29 는 아니고 11:30 부터 보인다', () {
      expect(isPredictionWindow(_mon(11, 29)), isFalse);
      expect(isPredictionWindow(_mon(11, 30)), isTrue);
    });

    test('12:59 는 보이고 13:00 부터는 사라진다', () {
      expect(isPredictionWindow(_mon(12, 59)), isTrue);
      expect(isPredictionWindow(_mon(13, 0)), isFalse);
    });

    test('주말에는 시간대여도 보이지 않는다', () {
      expect(isPredictionWindow(DateTime(2026, 10, 17, 12, 20)), isFalse);
      expect(isPredictionWindow(DateTime(2026, 10, 18, 12, 20)), isFalse);
    });

    test('서버에 묻는 시간은 11:20 부터다', () {
      expect(isPredictionFetchWindow(_mon(11, 19)), isFalse);
      expect(isPredictionFetchWindow(_mon(11, 20)), isTrue);
      expect(isPredictionFetchWindow(_mon(13, 0)), isFalse);
    });
  });

  group('현재 15분 구간', () {
    test('구간 시작 분을 돌려준다', () {
      expect(predictionSlotStart(_mon(11, 30)), 690);
      expect(predictionSlotStart(_mon(11, 44)), 690);
      expect(predictionSlotStart(_mon(11, 45)), 705);
      expect(predictionSlotStart(_mon(12, 0)), 720);
      expect(predictionSlotStart(_mon(12, 59)), 765);
    });

    test('노출 시간 밖이면 null', () {
      expect(predictionSlotStart(_mon(11, 29)), isNull);
      expect(predictionSlotStart(_mon(13, 0)), isNull);
    });
  });

  group('예측 대상 매장', () {
    final now = _mon(12, 20);

    test('오늘 제보가 0건이면 대상이다', () {
      expect(isPredictionTarget(_r(hasCrowdUpdate: false), now), isTrue);
    });

    test('마지막 제보가 30분 이내면 대상이 아니다', () {
      final r = _r(
        hasCrowdUpdate: true,
        updatedAt: now.subtract(const Duration(minutes: 30)),
      );
      expect(isPredictionTarget(r, now), isFalse);
    });

    test('마지막 제보가 31분 지났으면 대상이다', () {
      final r = _r(
        hasCrowdUpdate: true,
        updatedAt: now.subtract(const Duration(minutes: 31)),
      );
      expect(isPredictionTarget(r, now), isTrue);
    });

    test('제보 시각을 모르면 대상이 아니다', () {
      expect(isPredictionTarget(_r(hasCrowdUpdate: true), now), isFalse);
    });

    test('영업안함, 제보 비대상 매장은 대상이 아니다', () {
      expect(isPredictionTarget(_r(status: '영업안함'), now), isFalse);
      expect(isPredictionTarget(_r(crowdEnabled: false), now), isFalse);
    });
  });

  group('예측 값', () {
    test('level 을 앱 상태 문자열로 바꾼다', () {
      CrowdPrediction p(int level) => CrowdPrediction(
            restaurantId: 'r1',
            slotStartMinute: 720,
            sampleSize: 4,
            relaxProbability: 50,
            level: level,
          );
      expect(p(1).status, '여유로움');
      expect(p(2).status, '약간혼잡');
      expect(p(3).status, '자리없음');
    });

    test('서버 응답 한 줄을 읽는다', () {
      final p = CrowdPrediction.fromMap({
        'restaurant_id': 'abc',
        'slot_start_minute': 735,
        'sample_size': 5,
        'relax_probability': 71,
        'prob_level': 1,
        'prob_status': '여유로움',
      });
      expect(p.restaurantId, 'abc');
      expect(p.slotStartMinute, 735);
      expect(p.sampleSize, 5);
      expect(p.relaxProbability, 71);
      expect(p.level, 1);
    });
  });

  group('섹션에 붙는 예측 매장', () {
    Restaurant store(String id, double distance) => Restaurant(
          id: id,
          name: id,
          category: '한식',
          area: '정문',
          address: '정문',
          status: '여유로움',
          updated: 0,
          imageUrl: '',
          distance: distance,
          x: 0,
          y: 0,
          hours: '11:00 - 21:00',
          reports: const {},
          menu: const [],
          hasCrowdUpdate: false,
        );

    CrowdPrediction pred(String id, int prob, int level) => CrowdPrediction(
          restaurantId: id,
          slotStartMinute: 720,
          sampleSize: 4,
          relaxProbability: prob,
          level: level,
        );

    test('예측 값이 있는 매장만 모은다', () {
      final stores = [store('a', 10), store('b', 20)];
      final map = collectPredictions(
        stores,
        (r) => r.id == 'a' ? pred('a', 80, 1) : null,
      );
      expect(map.keys, ['a']);
    });

    test('섹션별로 확률 높은 순, 같으면 가까운 순으로 정렬한다', () {
      final stores = [store('a', 30), store('b', 20), store('c', 10), store('d', 5)];
      final map = {
        'a': pred('a', 75, 1),
        'b': pred('b', 90, 1),
        'c': pred('c', 75, 1),
        'd': pred('d', 50, 2),
      };
      expect(predictedForLevel(stores, map, 1).map((r) => r.id), ['b', 'c', 'a']);
      expect(predictedForLevel(stores, map, 2).map((r) => r.id), ['d']);
      expect(predictedForLevel(stores, map, 3), isEmpty);
    });
  });
}
