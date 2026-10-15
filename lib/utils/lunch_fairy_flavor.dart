import 'lunch_fairy_recommender.dart';
import 'restaurant_sort.dart';

/// 점메추 요정의 "게임스러운" 연출용 순수 로직.
/// 추천 결과 자체는 엔진([fairyRecommend])이 정하고, 여기서는 결과에 붙는 라벨과 말투만 만든다.
/// 희귀도는 이미 확인된 사실(최근 제보, 사장님 제보)로만 매기므로 허위 정보가 아니다.

enum FairyRarity { normal, rare, epic }

/// - 에픽: 최근 15분 내 입장가능이고, 그 상태를 사장님이 직접(또는 좌석 입력으로) 알려준 경우
/// - 레어: 최근 15분 내 입장가능 제보가 있는 경우
/// - 일반: 그 외 (라벨을 띄우지 않는다)
FairyRarity fairyRarity(FairyPick pick) {
  if (pick.tier != FairyTier.reportTarget) return FairyRarity.normal;
  if (pick.reason != FairyReason.freshRelaxed) return FairyRarity.normal;
  return isOwnerSourcedCrowd(pick.restaurant)
      ? FairyRarity.epic
      : FairyRarity.rare;
}

String fairyRarityLabel(FairyRarity rarity) {
  switch (rarity) {
    case FairyRarity.epic:
      return '✅ 사장님 픽';
    case FairyRarity.rare:
      return '🔥 따끈한 제보';
    case FairyRarity.normal:
      return '';
  }
}

/// 라벨 옆에 붙는 근거 문구.
String fairyRarityReason(FairyRarity rarity) {
  switch (rarity) {
    case FairyRarity.epic:
      return '사장님의 최신 제보가 있어요';
    case FairyRarity.rare:
      return '방금 올라온 제보가 있어요';
    case FairyRarity.normal:
      return '';
  }
}

/// 이유 코드별 말투 후보. `{name}`은 매장명, `{walk}`는 도보 분으로 치환된다.
List<String> fairyHeadlineTemplates(FairyReason reason, {required bool hasWalk}) {
  switch (reason) {
    case FairyReason.freshRelaxed:
      return const [
        '지금 {name} 입장 가능해요!',
        '{name}, 지금 자리가 여유로워요!',
        '오늘은 {name}! 지금 바로 들어갈 수 있대요.',
        '{name} 어때요? 방금 확인했더니 입장 가능해요!',
      ];
    case FairyReason.freshModerate:
      return const [
        '{name}, 조금 붐비지만 자리는 있다고 해요.',
        '{name}, 사람은 좀 있어도 앉을 수 있대요!',
        '{name} 어때요? 약간 붐비지만 자리는 있어요.',
      ];
    case FairyReason.nearby:
      return hasWalk
          ? const [
              '{name}, 걸어서 {walk}분이면 가요!',
              '{name}, 걸어서 {walk}분! 금방 도착해요.',
              '가까운 곳이라면 {name}! 걸어서 {walk}분이에요.',
            ]
          : const [
              '{name}, 가까워요!',
              '{name}, 바로 근처예요!',
            ];
    case FairyReason.soloFriendly:
      return const [
        '{name}, 혼자 가기 편한 곳이에요.',
        '혼밥이라면 {name}! 부담 없이 갈 수 있어요.',
      ];
    case FairyReason.dateFriendly:
      return const [
        '{name}, 밥약하기 좋은 곳이에요.',
        '밥약이라면 {name} 어떠세요?',
      ];
    case FairyReason.general:
      return const [
        '{name} 어떠세요?',
        '오늘은 {name} 어떠세요?',
        '{name}, 한번 가볼까요?',
      ];
  }
}

/// [seed]로 말투를 하나 고른다. 같은 seed면 같은 문구라 화면이 다시 그려져도 바뀌지 않는다.
String fairyHeadline(FairyPick pick, int seed) {
  final walk = pick.walkMinutes;
  final templates = fairyHeadlineTemplates(
    pick.reason,
    hasWalk: pick.reason != FairyReason.nearby || walk != null,
  );
  final t = templates[seed.abs() % templates.length];
  return t
      .replaceAll('{name}', pick.restaurant.name)
      .replaceAll('{walk}', walk?.toString() ?? '');
}

/// 시간대별 한마디. 혼잡도를 단정하지 않는 일반 문구이고,
/// 제보 대상 매장이 아닌 경우(컬렉션 전용)에는 쓰지 않으므로 null을 돌려준다.
String? fairyTimeNote(FairyPick pick, DateTime now) {
  if (pick.tier != FairyTier.reportTarget) return null;
  final m = now.hour * 60 + now.minute;
  if (m < 11 * 60 + 45) return '점심 피크 전에 미리 가볼까요?';
  if (m < 12 * 60 + 45) return '지금은 점심 피크 시간이에요. 서둘러요!';
  if (m < 13 * 60 + 30) return '피크가 슬슬 지나가는 시간이에요.';
  return '느긋하게 먹기 좋은 시간이에요.';
}
