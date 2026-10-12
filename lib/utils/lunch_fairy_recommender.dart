/// 점심메뉴 요정 추천 엔진 — 규칙 기반(AI 아님), 순수 함수.
///
/// 화면 문구는 여기서 만들지 않는다. 엔진은 "무엇을 왜 골랐는지"를 코드로만 돌려주고
/// 말투는 UI 계층이 입힌다. 테스트에서 `now`/`random`을 고정할 수 있게 둘 다 주입받는다.
library;

import 'dart:math' as math;

import '../models/restaurant.dart';
import 'business_hours.dart';

/// 최근 이 시간 안의 제보만 "신선"하다고 본다 (자리없음 제외 규칙도 동일 기준).
const Duration fairyFreshWindow = Duration(minutes: 15);

/// 결과 화면에서 혼잡도 뱃지를 보여주는 제보의 최대 경과 시간.
/// 이보다 오래된 제보는 뱃지를 아예 띄우지 않는다.
const Duration fairyBadgeWindow = Duration(minutes: 30);

/// 마감까지 이 시간 이상 남은 매장만 추천한다.
const Duration fairyClosingSoonWindow = Duration(minutes: 30);

/// 도보 분 → 미터 환산 (직선거리 기준 근사).
const double fairyWalkMetersPerMinute = 70;

/// 이 가격 미만 메뉴는 공기밥·음료 같은 사이드로 보고 예산 판정/메뉴 추천에서 뺀다.
/// (어드민이 지정한 대표메뉴는 이 하한과 무관하게 인정한다.)
const int fairyMealPriceFloor = 4000;

/// 홈 배너 노출 시간대 (평일, KST 기준 기기 로컬 시각).
const int fairyBannerStartHour = 11;
const int fairyBannerEndHour = 14;

bool isFairyBannerTime(DateTime now) =>
    now.weekday >= DateTime.monday &&
    now.weekday <= DateTime.friday &&
    now.hour >= fairyBannerStartHour &&
    now.hour < fairyBannerEndHour;

/// 누구랑 먹는지.
enum FairyCompanion { solo, friend, date }

/// 유저가 질문 시트에서 고른 조건. null = "상관없음".
class FairyRequest {
  /// 음식종류 (한식·중식·…). null이면 전체.
  final String? cuisine;

  /// 예산 상한(원). null이면 상관없음.
  final int? budgetLimit;

  /// 도보 한도(분). null이면 상관없음. 위치를 켠 사용자만 값을 가질 수 있다.
  final int? walkMinutes;

  /// 혼밥 / 친구랑 / 밥약.
  final FairyCompanion companion;

  /// 혼자가 아니면 true (친구랑·밥약).
  bool get withOthers => companion != FairyCompanion.solo;

  const FairyRequest({
    this.cuisine,
    this.budgetLimit,
    this.walkMinutes,
    this.companion = FairyCompanion.solo,
  });

  FairyRequest copyWithout({
    bool budget = false,
    bool cuisine = false,
    bool distance = false,
  }) =>
      FairyRequest(
        cuisine: cuisine ? null : this.cuisine,
        budgetLimit: budget ? null : budgetLimit,
        walkMinutes: distance ? null : walkMinutes,
        companion: companion,
      );
}

/// 현재 위치 (엔진이 Geolocator에 의존하지 않도록 값만 받는다).
class FairyPosition {
  final double latitude;
  final double longitude;
  const FairyPosition(this.latitude, this.longitude);
}

enum FairyTier { reportTarget, collectionOnly }

/// 추천 이유 코드. 문구는 UI에서 만든다.
enum FairyReason {
  /// 최근 15분 내 여유로움 제보
  freshRelaxed,

  /// 최근 15분 내 약간혼잡 제보
  freshModerate,

  /// 가까운 곳 선택 + 위치 기준 근거리
  nearby,

  /// 혼밥 선택 + 어드민 혼밥 표시 매장
  soloFriendly,

  /// 밥약 선택 + 어드민 밥약 표시 매장
  dateFriendly,

  /// 위 어디에도 해당하지 않는 일반 추천 (거리·인기 기반)
  general,
}

/// 조건이 없어서 풀어준 항목. 풀린 순서대로 담긴다.
enum FairyRelax { budget, cuisine, distance }

class FairyPick {
  final Restaurant restaurant;

  /// 추천 메뉴. 대표메뉴가 있으면 그것. 메뉴 정보가 없으면 null.
  /// 가격이 0이면 "미확인"이므로 표시하지 않는다.
  final MenuItem? menu;
  final FairyTier tier;
  final FairyReason reason;
  final List<FairyRelax> relaxed;

  /// 도보 분(직선 기준 근사). 위치를 모르면 null.
  final int? walkMinutes;

  /// 신선 제보일 때 제보 후 경과 분.
  final int? freshMinutes;

  const FairyPick({
    required this.restaurant,
    required this.menu,
    required this.tier,
    required this.reason,
    required this.relaxed,
    this.walkMinutes,
    this.freshMinutes,
  });
}

class FairyOutcome {
  final FairyPick? pick;

  /// true면 지금 영업 중인 후보 자체가 없다(이미 본 곳과 무관). false인데 pick이 null이면
  /// 후보를 전부 보여줬다는 뜻.
  final bool nothingOpen;

  const FairyOutcome({this.pick, this.nothingOpen = false});
}

/// 최근 [fairyFreshWindow] 안에 제보된 상태인가. status 만 보면 제보가 없는 매장도
/// '여유로움' 기본값을 갖고 있으므로 반드시 hasCrowdUpdate/updatedAt과 함께 본다.
bool isFairyFresh(Restaurant r, DateTime now) {
  if (!r.hasCrowdUpdate) return false;
  final at = r.updatedAt;
  if (at == null) return false;
  // 시계 오차로 updatedAt이 미래여도 difference가 음수가 되어 신선으로 취급된다.
  return now.difference(at) <= fairyFreshWindow;
}

/// 결과 화면 혼잡도 뱃지에 쓸 "제보 후 경과 분". 뱃지를 띄우면 안 되면 null.
/// 제보가 없거나 [fairyBadgeWindow](30분)보다 오래됐으면 null.
int? fairyCrowdBadgeMinutes(Restaurant r, DateTime now) {
  if (!r.hasCrowdUpdate) return null;
  final at = r.updatedAt;
  if (at == null) return null;
  final age = now.difference(at);
  if (age > fairyBadgeWindow) return null;
  return age.inMinutes < 0 ? 0 : age.inMinutes;
}

bool _isFreshFullRecently(Restaurant r, DateTime now) =>
    isFairyFresh(r, now) && r.status == '자리없음';

bool _isFreshPositive(Restaurant r, DateTime now) =>
    isFairyFresh(r, now) && (r.status == '여유로움' || r.status == '약간혼잡');

bool _isOpenForFairy(Restaurant r, DateTime now) {
  if (!r.isActive || r.status == '영업안함') return false;
  final bh = BusinessHoursData.fromDescription({
    'hours': r.hours,
    'hours_display': r.hours,
    'hours_periods': r.hoursPeriods,
  });
  return bh.isOpenAt(now) && bh.isOpenAt(now.add(fairyClosingSoonWindow));
}

double _distanceMeters(FairyPosition p, Restaurant r) {
  const earth = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(r.latitude - p.latitude);
  final dLng = rad(r.longitude - p.longitude);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(p.latitude)) *
          math.cos(rad(r.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earth * math.asin(math.min(1, math.sqrt(a.toDouble())));
}

/// 대표메뉴(최대 2개). 이름이 메뉴 목록과 일치하는 것만 유효하다.
List<MenuItem> fairySignatureMenus(Restaurant r) {
  final out = <MenuItem>[];
  for (final name in r.signatureMenus) {
    final sig = name.trim();
    if (sig.isEmpty) continue;
    for (final m in r.menu) {
      if (m.name.trim() == sig && !out.contains(m)) {
        out.add(m);
        break;
      }
    }
  }
  return out.length > 2 ? out.sublist(0, 2) : out;
}

/// 예산 판정에 쓸 대표 가격. 알 수 없으면 null(= 예산 필터를 통과시킨다).
/// 대표메뉴가 있으면 그중 가장 싼 가격 — 둘 중 하나라도 예산 안이면 갈 만하다.
/// 대표메뉴 중 하나라도 가격이 0(미확인)이면 판정할 수 없으므로 통과시킨다
/// (추천 메뉴 선택 단계가 0원을 "예산 안"으로 보는 것과 일치).
int? fairyBudgetPrice(Restaurant r) {
  final sigs = fairySignatureMenus(r);
  if (sigs.any((m) => m.price == 0)) return null;
  int? sigBest;
  for (final m in sigs) {
    if (sigBest == null || m.price < sigBest) sigBest = m.price;
  }
  if (sigBest != null) return sigBest;
  int? best;
  for (final m in r.menu) {
    if (m.price < fairyMealPriceFloor) continue;
    if (best == null || m.price < best) best = m.price;
  }
  return best;
}

MenuItem? fairyPickMenu(Restaurant r, int? budgetLimit, [math.Random? random]) {
  final sigs = fairySignatureMenus(r);
  if (sigs.isNotEmpty) {
    // 예산 안(또는 가격 미확인)인 대표메뉴가 있으면 그중에서, 없으면 첫 대표메뉴.
    // 대표가 2개면 "다른 데!"를 눌렀을 때 다른 메뉴가 나올 수 있게 무작위로 고른다.
    final fit = budgetLimit == null
        ? sigs
        : sigs.where((m) => m.price == 0 || m.price <= budgetLimit).toList();
    final pool = fit.isEmpty ? [sigs.first] : fit;
    return pool.length == 1
        ? pool.first
        : pool[(random ?? math.Random()).nextInt(pool.length)];
  }
  // 4천원 미만의 "확인된" 가격만 사이드로 본다. 0원은 가격 미확인(어드민이 이름만
  // 등록한 메뉴)이라 식사 메뉴로 인정한다.
  final meals = r.menu.where((m) => m.price >= fairyMealPriceFloor).toList();
  if (budgetLimit != null) {
    final within = meals.where((m) => m.price <= budgetLimit).toList()
      ..sort((a, b) => b.price.compareTo(a.price));
    if (within.isNotEmpty) return within.first;
  }
  for (final m in r.menu) {
    if (m.price == 0 && m.name.trim().isNotEmpty) return m;
  }
  return meals.isEmpty ? null : meals.first;
}

class _Scored {
  final Restaurant r;
  final double score;
  final double? meters;
  const _Scored(this.r, this.score, this.meters);
}

/// 추천 1건을 고른다.
///
/// 후보 풀 순서: ① 제보 대상 매장(조건 그대로) → ② 컬렉션 전용 매장(조건 그대로)
/// → ③ 예산 → 음식종류 → 거리 순으로 조건을 풀어 다시 ①②.
/// ①에 조건을 통과한 매장이 하나라도 남아 있으면 컬렉션 전용 매장은 혼밥/밥약 표시가 있어도
/// 나오지 않는다. ①이 소진(다른 곳 볼래요로 모두 본 경우)되어야 ②로 넘어가며, ② 안에서는
/// 혼밥/밥약 표시가 있는 매장이 점수상 앞선다.
/// 15분 안에 자리없음으로 제보된 매장은 어느 단계에서도 제외한다.
FairyOutcome fairyRecommend(
  List<Restaurant> restaurants,
  FairyRequest request, {
  required DateTime now,
  FairyPosition? position,
  Set<String> seenIds = const {},
  Set<String> bookmarkIds = const {},
  math.Random? random,
}) {
  final rng = random ?? math.Random();

  // 카페는 점심 식사 목적에 맞지 않아 항상 제외. 영업/마감 임박/자리없음 제외는 단계와 무관.
  final open = restaurants
      .where((r) =>
          r.category != '카페' &&
          _isOpenForFairy(r, now) &&
          !_isFreshFullRecently(r, now))
      .toList();
  if (open.isEmpty) return const FairyOutcome(nothingOpen: true);

  final unseen = open.where((r) => !seenIds.contains(r.id)).toList();

  final stages = <(FairyRequest, List<FairyRelax>)>[(request, const [])];
  final relaxed = <FairyRelax>[];
  var current = request;
  if (request.budgetLimit != null) {
    relaxed.add(FairyRelax.budget);
    current = current.copyWithout(budget: true);
    stages.add((current, List.of(relaxed)));
  }
  if (request.cuisine != null) {
    relaxed.add(FairyRelax.cuisine);
    current = current.copyWithout(cuisine: true);
    stages.add((current, List.of(relaxed)));
  }
  if (request.walkMinutes != null && position != null) {
    relaxed.add(FairyRelax.distance);
    current = current.copyWithout(distance: true);
    stages.add((current, List.of(relaxed)));
  }

  for (final (req, relaxedSoFar) in stages) {
    final matched = unseen.where((r) => _matches(r, req, position)).toList();
    if (matched.isEmpty) continue;

    final tier1 = matched.where((r) => r.crowdEnabled).toList();
    final tier2 = matched.where((r) => !r.crowdEnabled).toList();
    final pool = tier1.isNotEmpty ? tier1 : tier2;
    final tier = tier1.isNotEmpty ? FairyTier.reportTarget : FairyTier.collectionOnly;

    final pick = _choose(
      pool,
      tier,
      req,
      relaxedSoFar,
      now: now,
      position: position,
      bookmarkIds: bookmarkIds,
      rng: rng,
    );
    if (pick != null) return FairyOutcome(pick: pick);
  }
  return const FairyOutcome();
}

bool _matches(Restaurant r, FairyRequest req, FairyPosition? position) {
  if (req.cuisine != null && r.category != req.cuisine) return false;
  if (req.budgetLimit != null) {
    final price = fairyBudgetPrice(r);
    if (price != null && price > req.budgetLimit!) return false;
  }
  if (req.walkMinutes != null && position != null) {
    if (!r.hasMapLocation) return false;
    final limit = req.walkMinutes! * fairyWalkMetersPerMinute;
    if (_distanceMeters(position, r) > limit) return false;
  }
  return true;
}

FairyPick? _choose(
  List<Restaurant> pool,
  FairyTier tier,
  FairyRequest req,
  List<FairyRelax> relaxed, {
  required DateTime now,
  required FairyPosition? position,
  required Set<String> bookmarkIds,
  required math.Random rng,
}) {
  if (pool.isEmpty) return null;

  // 신선 제보(여유로움/약간혼잡)가 있는 매장이 하나라도 있으면 그 안에서만 고른다.
  // 없으면 혼잡도는 아예 점수에 반영하지 않는다(오래된 제보로 순위를 가르지 않음).
  // 컬렉션 전용 매장은 제보를 받지 않으므로 신선 제보 풀에는 들어가지 않는다.
  final fresh =
      pool.where((r) => r.crowdEnabled && _isFreshPositive(r, now)).toList();
  final useFresh = fresh.isNotEmpty;
  final candidates = useFresh ? fresh : pool;

  final hasPos = position != null;
  final walkSelected = req.walkMinutes != null && hasPos;
  final wCrowd = useFresh ? (walkSelected ? 30.0 : 40.0) : 0.0;
  final wDist = hasPos ? (walkSelected ? 35.0 : 20.0) : 0.0;
  const wPref = 20.0;
  const wPop = 10.0;
  const wInfo = 10.0;
  final wSum = wCrowd + wDist + wPref + wPop + wInfo;

  final maxPop = candidates
      .map((r) => r.popularityScore > 0 ? r.popularityScore : r.totalReports)
      .fold<int>(0, math.max);
  final refMeters = walkSelected
      ? req.walkMinutes! * fairyWalkMetersPerMinute
      : 800.0;

  final scored = <_Scored>[];
  for (final r in candidates) {
    var s = 0.0;
    if (useFresh) {
      final v = r.status == '여유로움'
          ? 1.0
          // 친구랑·밥약이면 약간혼잡은 같이 앉기 어려우니 크게 감점
          : (req.withOthers ? 0.25 : 0.55);
      s += wCrowd * v;
    }
    double? meters;
    if (hasPos && r.hasMapLocation) {
      meters = _distanceMeters(position, r);
      s += wDist * (1 - (meters / refMeters)).clamp(0.0, 1.0);
    }
    var pref = 0.4; // 미등록은 중립
    if (req.companion == FairyCompanion.solo && r.soloFriendly) pref += 0.4;
    if (req.companion == FairyCompanion.date && r.dateFriendly) pref += 0.4;
    // 친구랑은 전체에서 고르되, 혼자 가기 좋다고 표시된 매장은 후순위로 (제외는 아님).
    if (req.companion == FairyCompanion.friend && r.soloFriendly) pref -= 0.4;
    if (bookmarkIds.contains(r.id)) pref += 0.2;
    final price = fairyBudgetPrice(r);
    if (req.budgetLimit != null && price != null && price <= req.budgetLimit!) {
      pref += 0.2; // 가격이 확인된 매장을 약간 우대
    }
    s += wPref * pref.clamp(0.0, 1.0);
    final pop = r.popularityScore > 0 ? r.popularityScore : r.totalReports;
    s += wPop * (maxPop > 0 ? pop / maxPop : 0.0);
    var info = 0.0;
    if (fairySignatureMenus(r).isNotEmpty) info += 0.6;
    if (r.menu.isNotEmpty) info += 0.4;
    s += wInfo * info;
    scored.add(_Scored(r, s / wSum, meters));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));

  // 항상 1등만 주면 같은 곳이 반복되므로 상위 3곳 중 점수 비례로 뽑는다.
  final top = scored.take(3).toList();
  final total = top.fold<double>(0, (sum, e) => sum + e.score + 0.05);
  var roll = rng.nextDouble() * total;
  _Scored chosen = top.first;
  for (final e in top) {
    roll -= e.score + 0.05;
    if (roll <= 0) {
      chosen = e;
      break;
    }
  }

  final r = chosen.r;
  FairyReason reason;
  int? freshMinutes;
  if (useFresh) {
    reason = r.status == '여유로움'
        ? FairyReason.freshRelaxed
        : FairyReason.freshModerate;
    freshMinutes = r.updatedAt == null
        ? null
        : now.difference(r.updatedAt!).inMinutes.clamp(0, 99999);
  } else if (walkSelected) {
    reason = FairyReason.nearby;
  } else if (req.companion == FairyCompanion.solo && r.soloFriendly) {
    reason = FairyReason.soloFriendly;
  } else if (req.companion == FairyCompanion.date && r.dateFriendly) {
    reason = FairyReason.dateFriendly;
  } else {
    reason = FairyReason.general;
  }

  return FairyPick(
    restaurant: r,
    menu: fairyPickMenu(r, req.budgetLimit, rng),
    // 승격된 컬렉션 전용 매장이 뽑힐 수 있으니 매장 기준으로 정한다 (뱃지 노출 판단에 쓰임).
    tier: r.crowdEnabled ? FairyTier.reportTarget : FairyTier.collectionOnly,
    reason: reason,
    relaxed: relaxed,
    walkMinutes: chosen.meters == null
        ? null
        : math.max(1, (chosen.meters! / fairyWalkMetersPerMinute).round()),
    freshMinutes: freshMinutes,
  );
}
