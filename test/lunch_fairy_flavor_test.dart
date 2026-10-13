import 'package:campus_lunch/models/restaurant.dart';
import 'package:campus_lunch/utils/lunch_fairy_flavor.dart';
import 'package:campus_lunch/utils/lunch_fairy_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

Restaurant _r({String name = '기꾸스시', String source = 'user'}) => Restaurant(
      id: 'x',
      name: name,
      category: '일식',
      area: '정문',
      address: 'x',
      status: '여유로움',
      updated: 3,
      imageUrl: '',
      distance: 0,
      x: 0,
      y: 0,
      hours: '',
      reports: const {},
      menu: const [],
    ).copyWith(
      hasCrowdUpdate: true,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      crowdBaseSource: source,
    );

FairyPick _pick({
  required FairyReason reason,
  Restaurant? restaurant,
  FairyTier tier = FairyTier.reportTarget,
  int? walk,
}) =>
    FairyPick(
      restaurant: restaurant ?? _r(),
      menu: null,
      tier: tier,
      reason: reason,
      relaxed: const [],
      walkMinutes: walk,
    );

void main() {
  group('fairyRarity', () {
    test('최근 입장가능 + 사장님 제보 → 에픽', () {
      final p = _pick(
          reason: FairyReason.freshRelaxed, restaurant: _r(source: 'owner'));
      expect(fairyRarity(p), FairyRarity.epic);
    });

    test('최근 입장가능 + 유저 제보 → 레어', () {
      final p = _pick(reason: FairyReason.freshRelaxed);
      expect(fairyRarity(p), FairyRarity.rare);
    });

    test('입장가능이 아닌 이유(약간혼잡·근거리 등)는 일반', () {
      for (final reason in [
        FairyReason.freshModerate,
        FairyReason.nearby,
        FairyReason.soloFriendly,
        FairyReason.dateFriendly,
        FairyReason.general,
      ]) {
        expect(fairyRarity(_pick(reason: reason)), FairyRarity.normal,
            reason: '$reason');
      }
    });

    test('컬렉션 전용 매장은 제보가 있어 보여도 항상 일반', () {
      final p = _pick(
        reason: FairyReason.freshRelaxed,
        restaurant: _r(source: 'owner'),
        tier: FairyTier.collectionOnly,
      );
      expect(fairyRarity(p), FairyRarity.normal);
    });

    test('일반은 라벨·근거 문구가 비어 있다(화면에 띄우지 않음)', () {
      expect(fairyRarityLabel(FairyRarity.normal), '');
      expect(fairyRarityReason(FairyRarity.normal), '');
      expect(fairyRarityLabel(FairyRarity.epic), '에픽');
      expect(fairyRarityLabel(FairyRarity.rare), '레어');
    });
  });

  group('fairyHeadline', () {
    test('같은 seed는 항상 같은 문구', () {
      final p = _pick(reason: FairyReason.freshRelaxed);
      expect(fairyHeadline(p, 7), fairyHeadline(p, 7));
    });

    test('seed가 달라지면 문구가 달라질 수 있다(후보 2개 이상)', () {
      final p = _pick(reason: FairyReason.freshRelaxed);
      final all = {for (var s = 0; s < 8; s++) fairyHeadline(p, s)};
      expect(all.length, greaterThan(1));
    });

    test('모든 이유 코드·seed에서 매장명이 들어가고 치환되지 않은 자리표시자가 없다', () {
      for (final reason in FairyReason.values) {
        for (var s = 0; s < 12; s++) {
          final p = _pick(
            reason: reason,
            walk: reason == FairyReason.nearby ? 4 : null,
          );
          final text = fairyHeadline(p, s);
          expect(text, contains('기꾸스시'), reason: '$reason/$s');
          expect(text, isNot(contains('{')), reason: '$reason/$s');
        }
      }
    });

    test('도보 분이 있는 근거리 추천은 분 수가 들어간다', () {
      final p = _pick(reason: FairyReason.nearby, walk: 4);
      for (var s = 0; s < 6; s++) {
        expect(fairyHeadline(p, s), contains('4분'));
      }
    });

    test('도보 분을 모르는 근거리 추천은 분 표현을 쓰지 않는다', () {
      final p = _pick(reason: FairyReason.nearby);
      for (var s = 0; s < 6; s++) {
        expect(fairyHeadline(p, s), isNot(contains('분')));
      }
    });

    test('음수 seed도 안전', () {
      final p = _pick(reason: FairyReason.general);
      expect(() => fairyHeadline(p, -5), returnsNormally);
    });
  });

  group('fairyTimeNote', () {
    final p = _pick(reason: FairyReason.general);

    test('시간대별 문구', () {
      expect(fairyTimeNote(p, DateTime(2026, 10, 13, 11, 30)),
          '점심 피크 전에 미리 가볼까요?');
      expect(fairyTimeNote(p, DateTime(2026, 10, 13, 12, 10)),
          '지금은 점심 피크 시간이에요. 서둘러요!');
      expect(fairyTimeNote(p, DateTime(2026, 10, 13, 13, 10)),
          '피크가 슬슬 지나가는 시간이에요.');
      expect(fairyTimeNote(p, DateTime(2026, 10, 13, 13, 40)),
          '느긋하게 먹기 좋은 시간이에요.');
    });

    test('컬렉션 전용 매장에는 혼잡을 암시하는 한마디를 붙이지 않는다', () {
      final c = _pick(
        reason: FairyReason.general,
        tier: FairyTier.collectionOnly,
      );
      expect(fairyTimeNote(c, DateTime(2026, 10, 13, 12, 10)), isNull);
    });
  });
}
