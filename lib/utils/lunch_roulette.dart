import 'dart:math' as math;

import '../models/restaurant.dart';
import 'lunch_fairy_recommender.dart';

/// 점심 룰렛의 칸 구성과 결과 선택. 화면과 분리한 순수 로직이다.
///
/// 칸 구성: 최근 15분 이내 "입장가능(여유로움)" 제보 매장을 최대 [rouletteMaxFresh]곳 먼저 넣고,
/// 나머지는 음식 종류가 골고루 퍼지도록 채워 총 [rouletteMaxSlots]곳으로 만든다.
/// 멈추는 곳은 칸 구성과 무관하게 균등 랜덤이다([rouletteWinnerIndex]).

const int rouletteMaxSlots = 8;
const int rouletteMaxFresh = 4;

/// 이보다 적으면 룰렛이 의미가 없어 돌리기를 막는다.
const int rouletteMinSlots = 3;

enum RouletteShortage {
  /// 충분하다 (칸이 [rouletteMaxSlots]개).
  none,

  /// 칸이 [rouletteMinSlots]~[rouletteMaxSlots]-1개뿐이다. 있는 만큼만 돌린다.
  fewer,

  /// 선택한 종류만으로는 [rouletteMinSlots]곳이 안 돼 돌릴 수 없다.
  blocked,
}

class RouletteDeal {
  /// 룰렛 칸. [RouletteShortage.blocked]이면 비어 있다.
  final List<Restaurant> slots;
  final RouletteShortage shortage;

  /// 선택한 음식 종류(비어 있으면 전체) 조건을 만족하는 후보 수.
  final int poolSize;

  /// 다른 음식으로 부족분을 채웠는지.
  final bool mixedIn;

  /// 선택한 종류에서 온 칸 수 (mixedIn일 때만 의미가 있다).
  final int selectedCount;

  const RouletteDeal({
    required this.slots,
    required this.shortage,
    required this.poolSize,
    this.mixedIn = false,
    this.selectedCount = 0,
  });

  bool get canSpin => slots.length >= rouletteMinSlots;
}

/// 최근 15분 안에 "여유로움(입장가능)"으로 제보된 매장인가.
/// 약간혼잡은 포함하지 않는다. 제보를 받지 않는 컬렉션 전용 매장도 제외한다.
bool isFreshRelaxed(Restaurant r, DateTime now) =>
    r.crowdEnabled && isFairyFresh(r, now) && r.status == '여유로움';

/// 룰렛 후보가 될 수 있는 모든 매장 (같이 고르기 목록용). 음식 종류 → 이름 순.
List<Restaurant> rouletteEligible(List<Restaurant> restaurants, DateTime now) {
  final list = restaurants.where((r) => fairyIsEligible(r, now)).toList()
    ..sort((a, b) {
      final c = a.category.compareTo(b.category);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  return list;
}

/// 제보 대상 매장이 하나라도 있으면 그 안에서만 고른다. 컬렉션 전용 매장은
/// 제보 대상이 모두 소진됐을 때만 후보가 된다 (점메추 요정과 같은 규칙).
List<Restaurant> _tierPool(List<Restaurant> list) {
  final reportable = list.where((r) => r.crowdEnabled).toList();
  return reportable.isNotEmpty ? reportable : list;
}

/// 음식 종류가 골고루 퍼지게 [n]곳을 뽑는다. [counts]에는 이미 뽑힌 종류별 개수가 있고
/// 뽑을 때마다 갱신된다. 가장 적게 뽑힌 종류에서 무작위로 한 곳씩 가져온다.
List<Restaurant> _pickBalanced(
  List<Restaurant> candidates,
  int n,
  Map<String, int> counts,
  math.Random rng,
) {
  final byCategory = <String, List<Restaurant>>{};
  for (final r in candidates) {
    byCategory.putIfAbsent(r.category, () => []).add(r);
  }
  for (final list in byCategory.values) {
    list.shuffle(rng);
  }
  final picked = <Restaurant>[];
  while (picked.length < n) {
    final available =
        byCategory.entries.where((e) => e.value.isNotEmpty).toList();
    if (available.isEmpty) break;
    final fewest = available.map((e) => counts[e.key] ?? 0).reduce(math.min);
    final ties =
        available.where((e) => (counts[e.key] ?? 0) == fewest).toList();
    final chosen = ties[rng.nextInt(ties.length)];
    picked.add(chosen.value.removeLast());
    counts[chosen.key] = (counts[chosen.key] ?? 0) + 1;
  }
  return picked;
}

/// 룰렛 칸을 구성한다.
///
/// [cuisines]가 비어 있으면 전체. [mixIn]이 true이면 선택한 종류가 모자랄 때
/// 다른 음식으로 부족분을 채운다. [excludeIds]에 든 매장은 후보에서 뺀다.
/// [avoidIds]에 든 매장은 되도록 피하되, 칸이 모자라면 마지막에 다시 채운다
/// ("후보 바꾸기"를 눌러도 칸 수가 줄지 않게 하려는 용도).
RouletteDeal dealRoulette(
  List<Restaurant> restaurants, {
  required DateTime now,
  Set<String> cuisines = const {},
  bool mixIn = false,
  Set<String> excludeIds = const {},
  Set<String> avoidIds = const {},
  math.Random? random,
  int size = rouletteMaxSlots,
}) {
  final rng = random ?? math.Random();
  final eligible = restaurants
      .where((r) => !excludeIds.contains(r.id) && fairyIsEligible(r, now))
      .toList();
  final matched = cuisines.isEmpty
      ? eligible
      : eligible.where((r) => cuisines.contains(r.category)).toList();
  final pool = _tierPool(matched);

  List<Restaurant> pickFrom(
      List<Restaurant> source, int n, Map<String, int> counts) {
    final fresh = source.where((r) => isFreshRelaxed(r, now)).toList();
    final first =
        _pickBalanced(fresh, math.min(rouletteMaxFresh, n), counts, rng);
    // 입장가능 매장은 최대 [rouletteMaxFresh]곳만 넣고, 넘친 매장은 일반 칸에서도 뺀다.
    // 일반 후보만으로 칸이 모자랄 때에 한해 넘친 매장으로 채운다.
    final freshIds = fresh.map((r) => r.id).toSet();
    final rest = source.where((r) => !freshIds.contains(r.id)).toList();
    final more = _pickBalanced(rest, n - first.length, counts, rng);
    final firstIds = first.map((r) => r.id).toSet();
    final overflow = fresh.where((r) => !firstIds.contains(r.id)).toList();
    final short = n - first.length - more.length;
    final topUp = short > 0
        ? _pickBalanced(overflow, short, counts, rng)
        : <Restaurant>[];
    return [...first, ...more, ...topUp];
  }

  final counts = <String, int>{};
  List<Restaurant> pickAvoiding(
      List<Restaurant> source, int n, Map<String, int> counts) {
    if (avoidIds.isEmpty) return pickFrom(source, n, counts);
    final preferred = source.where((r) => !avoidIds.contains(r.id)).toList();
    final picked = pickFrom(preferred, n, counts);
    if (picked.length >= n) return picked;
    // 모자라면 피하던 매장으로 채운다. 입장가능 매장은 4곳을 넘기지 않도록 일반 매장을 먼저 쓴다.
    final back = source.where((r) => avoidIds.contains(r.id)).toList();
    final backPlain = back.where((r) => !isFreshRelaxed(r, now)).toList();
    final backFresh = back.where((r) => isFreshRelaxed(r, now)).toList();
    final pickedFresh = picked.where((r) => isFreshRelaxed(r, now)).length;
    final out = [...picked];
    out.addAll(_pickBalanced(backPlain, n - out.length, counts, rng));
    if (out.length < n) {
      final room = math.max(0, rouletteMaxFresh - pickedFresh);
      out.addAll(_pickBalanced(
          backFresh, math.min(room, n - out.length), counts, rng));
    }
    if (out.length < n) {
      final used = out.map((r) => r.id).toSet();
      out.addAll(_pickBalanced(
          backFresh.where((r) => !used.contains(r.id)).toList(),
          n - out.length,
          counts,
          rng));
    }
    return out;
  }

  final selected = pickAvoiding(pool, size, counts);
  var slots = selected;
  var mixed = false;

  if (mixIn && cuisines.isNotEmpty && slots.length < size) {
    final others = _tierPool(
        eligible.where((r) => !cuisines.contains(r.category)).toList());
    final extra = _pickBalanced(others, size - slots.length, counts, rng);
    if (extra.isNotEmpty) {
      slots = [...slots, ...extra];
      mixed = true;
    }
  }

  if (slots.length < rouletteMinSlots) {
    return RouletteDeal(
      slots: const [],
      shortage: RouletteShortage.blocked,
      poolSize: pool.length,
    );
  }

  slots = List.of(slots)..shuffle(rng);
  return RouletteDeal(
    slots: slots,
    shortage:
        slots.length >= size ? RouletteShortage.none : RouletteShortage.fewer,
    poolSize: pool.length,
    mixedIn: mixed,
    selectedCount: selected.length,
  );
}

/// 멈추는 칸. 결과는 반드시 이 값으로 먼저 정하고, 룰렛 각도는 이 칸에 맞춰 계산한다.
int rouletteWinnerIndex(int slotCount, math.Random rng) =>
    rng.nextInt(slotCount);

/// 칸 구성 결과에 대한 안내 문구. 안내가 필요 없으면 null.
String? rouletteNotice(RouletteDeal deal, Set<String> cuisines) {
  final label =
      cuisines.isEmpty ? '' : '${(cuisines.toList()..sort()).join('·')} ';
  if (deal.mixedIn) {
    return '$label${deal.selectedCount}곳 + 다른 음식으로 채웠어요.';
  }
  switch (deal.shortage) {
    case RouletteShortage.none:
      return null;
    case RouletteShortage.fewer:
      final n = deal.slots.length;
      return '지금 영업 중인 $label매장이 $n곳뿐이에요. $n칸으로 돌릴게요!';
    case RouletteShortage.blocked:
      return deal.poolSize == 0
          ? '지금 영업 중인 $label매장이 없어요.'
          : '지금 영업 중인 $label매장이 ${deal.poolSize}곳뿐이라 룰렛을 돌리기 어려워요.';
  }
}
