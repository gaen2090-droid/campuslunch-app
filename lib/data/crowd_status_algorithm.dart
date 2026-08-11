/// 혼잡도 계산 — 대표 status는 항상 "가장 최신 제보"를 그대로 반영한다.
/// 1=여유로움, 2=약간혼잡, 3=자리없음 (셋 다 독립된 동급 단계)
/// 다수결/일치도는 confidence 산정에만 쓰이고, status 결정에는 쓰이지 않는다.
library;

const crowdLevelRelaxed = 1;
const crowdLevelModerate = 2;
const crowdLevelFull = 3;
const crowdLevelMin = crowdLevelRelaxed;
const crowdLevelMax = crowdLevelFull;

String crowdLevelToStatus(int level) {
  switch (level) {
    case crowdLevelRelaxed:
      return '여유로움';
    case crowdLevelModerate:
      return '약간혼잡';
    case crowdLevelFull:
      return '자리없음';
    default:
      return '여유로움';
  }
}

int crowdStatusToLevel(String status) {
  switch (status) {
    case '여유로움':
      return crowdLevelRelaxed;
    case '약간혼잡':
      return crowdLevelModerate;
    case '자리없음':
      return crowdLevelFull;
    default:
      return crowdLevelRelaxed;
  }
}

int? parseDisplayLevel(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final trimmed = value.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt.clamp(crowdLevelMin, crowdLevelMax);
    return crowdStatusToLevel(trimmed);
  }
  return null;
}

class CrowdStatusResult {
  final int displayLevel;
  final String baseSource;
  final String confidence;
  final int reportCount;
  final bool refreshUpdatedAt;
  /// displayLevel을 결정한 제보(사장님 5분 우선권 적용 후)의 시각. 계산 대상 제보가
  /// 전혀 없을 때만 null.
  final DateTime? adoptedAt;

  const CrowdStatusResult({
    required this.displayLevel,
    required this.baseSource,
    required this.confidence,
    required this.reportCount,
    this.refreshUpdatedAt = false,
    this.adoptedAt,
  });

  String get displayStatus => crowdLevelToStatus(displayLevel);
}

/// 제보 1건의 레벨과 시각 (소스 무관 — owner/user 공통)
class LevelReport {
  final int level;
  final DateTime at;

  const LevelReport({required this.level, required this.at});
}

class CrowdStatusComputeParams {
  /// 이번 영업 세션 내 사장님 최신 제보 (없으면 null)
  final LevelReport? ownerLatest;
  /// 이번 영업 세션 내(또는 최근 20분 내) 유저 제보 — 유저당 1건, 시각 내림차순일 필요는 없음
  final List<LevelReport> userReports;
  /// 직전 표시 레벨 (confidence 계산 보조용 — status 결정에는 쓰이지 않음)
  final int? currentDisplayLevel;
  final DateTime now;

  const CrowdStatusComputeParams({
    required this.ownerLatest,
    required this.userReports,
    required this.currentDisplayLevel,
    required this.now,
  });
}

class _Consensus {
  final int level;
  final int count;
  final double ratio;
  final int total;

  const _Consensus({
    required this.level,
    required this.count,
    required this.ratio,
    required this.total,
  });
}

_Consensus? _dominantConsensus(List<int> levels) {
  if (levels.isEmpty) return null;
  final counts = <int, int>{};
  for (final level in levels) {
    counts[level] = (counts[level] ?? 0) + 1;
  }
  var bestLevel = crowdLevelRelaxed;
  var bestCount = 0;
  for (final entry in counts.entries) {
    if (entry.value > bestCount ||
        (entry.value == bestCount && entry.key > bestLevel)) {
      bestCount = entry.value;
      bestLevel = entry.key;
    }
  }
  return _Consensus(
    level: bestLevel,
    count: bestCount,
    ratio: bestCount / levels.length,
    total: levels.length,
  );
}

bool _isSplitOpinion(List<int> levels) {
  if (levels.length < 2) return false;
  final counts = <int, int>{};
  for (final level in levels) {
    counts[level] = (counts[level] ?? 0) + 1;
  }
  final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
  final leaders = counts.values.where((c) => c == maxCount).length;
  return leaders > 1;
}

/// 최근 두 제보(시각 내림차순)가 같은 레벨인지 — confidence 판단 보조
bool _latestTwoAgree(List<LevelReport> sortedDesc) {
  if (sortedDesc.length < 2) return false;
  return sortedDesc[0].level == sortedDesc[1].level;
}

/// 최근 두 제보가 크게 다른지(레벨 차 2 이상) — confidence 판단 보조
bool _latestTwoConflict(List<LevelReport> sortedDesc) {
  if (sortedDesc.length < 2) return false;
  return (sortedDesc[0].level - sortedDesc[1].level).abs() >= 2;
}

/// confidence 산정 — status 결정과 무관, 다수결/최근 일치도로만 판단
String _computeConfidence({
  required LevelReport? ownerLatest,
  required LevelReport? userLatest,
  required List<LevelReport> allSortedDesc,
}) {
  // 사장님 최신 제보와 유저 최신 제보가 일치 → high
  if (ownerLatest != null &&
      userLatest != null &&
      ownerLatest.level == userLatest.level) {
    return 'high';
  }

  final levels = allSortedDesc.map((r) => r.level).toList();
  final dom = _dominantConsensus(levels);

  // 의견이 완전히 갈림(동률) → low
  if (_isSplitOpinion(levels)) return 'low';

  // 최신 제보와 직전 제보가 크게 다름 → low
  if (_latestTwoConflict(allSortedDesc)) return 'low';

  // 제보가 1건뿐
  if (allSortedDesc.length == 1) {
    return 'low';
  }

  // 최신 제보와 직전 제보가 일치 → high
  if (_latestTwoAgree(allSortedDesc)) return 'high';

  // 압도적 다수(5건↑, 80%↑) → high
  if (dom != null && dom.total >= 5 && dom.ratio >= 0.8) return 'high';

  // 다수가 어느 정도 일치(60%↑) → medium
  if (dom != null && dom.ratio >= 0.6) return 'medium';

  return 'medium';
}

/// 사장님 제보 후 이 시간 동안은 더 최신인 유저 제보가 있어도 사장님 값을 우선한다.
const Duration ownerPriorityWindow = Duration(minutes: 5);

CrowdStatusResult computeCrowdStatus(CrowdStatusComputeParams params) {
  final owner = params.ownerLatest;
  final users = params.userReports;
  final all = <LevelReport>[
    if (owner != null) owner,
    ...users,
  ]..sort((a, b) => b.at.compareTo(a.at));

  if (all.isEmpty) {
    // 계산 대상 제보가 전혀 없으면 직전 표시값 유지, 없으면 기본값
    final fallback = params.currentDisplayLevel ?? crowdLevelRelaxed;
    return CrowdStatusResult(
      displayLevel: fallback,
      baseSource: 'user',
      confidence: 'low',
      reportCount: 0,
      refreshUpdatedAt: false,
    );
  }

  final userLatest = users.isEmpty
      ? null
      : users.reduce((a, b) => a.at.isAfter(b.at) ? a : b);

  // 사장님 제보가 5분 이내면, 그보다 늦은 유저 제보가 있어도 사장님 값을 우선한다.
  final ownerWithinPriorityWindow = owner != null &&
      params.now.difference(owner.at) <= ownerPriorityWindow;

  final latest = ownerWithinPriorityWindow ? owner : all.first;

  final baseSource = owner != null && identical(latest, owner) ? 'owner' : 'user';

  final confidence = _computeConfidence(
    ownerLatest: owner,
    userLatest: userLatest,
    allSortedDesc: all,
  );

  final changed = params.currentDisplayLevel != latest.level;

  return CrowdStatusResult(
    displayLevel: latest.level,
    baseSource: baseSource,
    confidence: confidence,
    reportCount: users.length,
    refreshUpdatedAt: changed,
    adoptedAt: latest.at,
  );
}

/// 추천 정렬용 freshness (0~100, 높을수록 최신)
int freshnessScore(int minutesSinceUpdate) {
  if (minutesSinceUpdate <= 15) return 100;
  if (minutesSinceUpdate <= 60) return 60;
  if (minutesSinceUpdate <= 24 * 60) return 20;
  return 5;
}
