/// PDF 「혼잡도 계산 로직 개편 2」 — 유저 제보 중심 + 사장님 보정
/// 1=여유로움, 2=약간혼잡, 3=자리없음
library;

const crowdLevelRelaxed = 1;
const crowdLevelModerate = 2;
const crowdLevelFull = 3;

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
    if (asInt != null) return asInt.clamp(1, 3);
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

  const CrowdStatusResult({
    required this.displayLevel,
    required this.baseSource,
    required this.confidence,
    required this.reportCount,
    this.refreshUpdatedAt = false,
  });

  String get displayStatus => crowdLevelToStatus(displayLevel);
}

class CrowdStatusComputeParams {
  final int? ownerLevel;
  final List<int> userLevels20;
  final int? currentDisplayLevel;
  final DateTime? statusStartedAt;
  final DateTime? lastUpdatedAt;
  final DateTime? businessSessionStart;
  final DateTime now;
  final bool ownerJustReported;

  const CrowdStatusComputeParams({
    required this.ownerLevel,
    required this.userLevels20,
    required this.currentDisplayLevel,
    required this.statusStartedAt,
    this.lastUpdatedAt,
    this.businessSessionStart,
    required this.now,
    this.ownerJustReported = false,
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

int _moveOneStepToward(int base, int target) {
  if (target > base) {
    return (base + 1).clamp(crowdLevelRelaxed, crowdLevelFull);
  }
  if (target < base) {
    return (base - 1).clamp(crowdLevelRelaxed, crowdLevelFull);
  }
  return base;
}

int _clampStepChange({
  required int? current,
  required int target,
  required bool allowFullJump,
}) {
  if (current == null) return target;
  if (current == target) return current;
  final diff = (target - current).abs();
  if (diff >= 2 && !allowFullJump) {
    return _moveOneStepToward(current, target);
  }
  return target;
}

bool isStrongUserSignal(List<int> userLevels) {
  final dom = _dominantConsensus(userLevels);
  return dom != null && dom.total >= 5 && dom.ratio >= 0.8;
}

CrowdStatusResult _keepCurrent({
  required int current,
  required String baseSource,
  required String confidence,
  required int reportCount,
  bool refreshUpdatedAt = false,
}) {
  return CrowdStatusResult(
    displayLevel: current,
    baseSource: baseSource,
    confidence: confidence,
    reportCount: reportCount,
    refreshUpdatedAt: refreshUpdatedAt,
  );
}

CrowdStatusResult _computeUserOnly({
  required int? current,
  required List<int> users,
}) {
  final n = users.length;
  if (n == 0) {
    return _keepCurrent(
      current: current ?? crowdLevelRelaxed,
      baseSource: 'user',
      confidence: 'low',
      reportCount: 0,
    );
  }

  if (n == 1) {
    final userLevel = users.first;
    if (current == null) {
      return CrowdStatusResult(
        displayLevel: userLevel,
        baseSource: 'user',
        confidence: 'low',
        reportCount: 1,
        refreshUpdatedAt: true,
      );
    }
    if (userLevel == current) {
      return _keepCurrent(
        current: current,
        baseSource: 'user',
        confidence: 'medium',
        reportCount: 1,
        refreshUpdatedAt: true,
      );
    }
    return _keepCurrent(
      current: current,
      baseSource: 'user',
      confidence: 'medium',
      reportCount: 1,
    );
  }

  if (n == 2) {
    final same = users[0] == users[1];
    if (same) {
      final agreed = users.first;
      if (current == null) {
        return CrowdStatusResult(
          displayLevel: agreed,
          baseSource: 'user',
          confidence: 'medium',
          reportCount: 2,
          refreshUpdatedAt: true,
        );
      }
      final next = _clampStepChange(
        current: current,
        target: agreed,
        allowFullJump: false,
      );
      return CrowdStatusResult(
        displayLevel: next,
        baseSource: 'user',
        confidence: 'medium',
        reportCount: 2,
        refreshUpdatedAt: next != current || agreed == current,
      );
    }
    if (current == null) {
      return CrowdStatusResult(
        displayLevel: crowdLevelModerate,
        baseSource: 'user',
        confidence: 'low',
        reportCount: 2,
        refreshUpdatedAt: true,
      );
    }
    return _keepCurrent(
      current: current,
      baseSource: 'user',
      confidence: 'medium',
      reportCount: 2,
    );
  }

  final dom = _dominantConsensus(users)!;
  if (_isSplitOpinion(users)) {
    if (current == null) {
      return CrowdStatusResult(
        displayLevel: crowdLevelModerate,
        baseSource: 'user',
        confidence: 'low',
        reportCount: n,
        refreshUpdatedAt: true,
      );
    }
    return _keepCurrent(
      current: current,
      baseSource: 'user',
      confidence: 'medium',
      reportCount: n,
    );
  }

  if (dom.total >= 5 && dom.ratio >= 0.8) {
    if (current == null) {
      return CrowdStatusResult(
        displayLevel: dom.level,
        baseSource: 'user',
        confidence: 'high',
        reportCount: n,
        refreshUpdatedAt: true,
      );
    }
    return CrowdStatusResult(
      displayLevel: dom.level,
      baseSource: 'user',
      confidence: 'high',
      reportCount: n,
      refreshUpdatedAt: dom.level != current || dom.level == current,
    );
  }

  if (dom.ratio >= 0.6) {
    if (current == null) {
      return CrowdStatusResult(
        displayLevel: dom.level,
        baseSource: 'user',
        confidence: 'medium',
        reportCount: n,
        refreshUpdatedAt: true,
      );
    }
    final allowFull = dom.total >= 5 && dom.ratio >= 0.8;
    final next = _clampStepChange(
      current: current,
      target: dom.level,
      allowFullJump: allowFull,
    );
    return CrowdStatusResult(
      displayLevel: next,
      baseSource: 'user',
      confidence: 'medium',
      reportCount: n,
      refreshUpdatedAt: next != current,
    );
  }

  if (current == null) {
    return CrowdStatusResult(
      displayLevel: crowdLevelModerate,
      baseSource: 'user',
      confidence: 'low',
      reportCount: n,
      refreshUpdatedAt: true,
    );
  }
  return _keepCurrent(
    current: current,
    baseSource: 'user',
    confidence: 'medium',
    reportCount: n,
  );
}

CrowdStatusResult _computeOwnerAndUser({
  required int owner,
  required int? current,
  required List<int> users,
}) {
  final n = users.length;
  final displayBase = current ?? owner;

  if (n >= 1 && users.every((u) => u == owner)) {
    return CrowdStatusResult(
      displayLevel: owner,
      baseSource: 'owner',
      confidence: 'high',
      reportCount: n,
      refreshUpdatedAt: true,
    );
  }

  if (n >= 1 && n <= 2) {
    return _keepCurrent(
      current: displayBase,
      baseSource: 'owner',
      confidence: 'high',
      reportCount: n,
    );
  }

  final dom = _dominantConsensus(users);
  if (dom == null || _isSplitOpinion(users)) {
    return _keepCurrent(
      current: displayBase,
      baseSource: 'owner',
      confidence: 'medium',
      reportCount: n,
    );
  }

  if (dom.total >= 5 && dom.ratio >= 0.8) {
    return CrowdStatusResult(
      displayLevel: dom.level,
      baseSource: 'user',
      confidence: 'high',
      reportCount: n,
      refreshUpdatedAt: dom.level != displayBase || dom.level == owner,
    );
  }

  if (dom.total >= 3 && dom.ratio >= 0.7) {
    final next = _moveOneStepToward(owner, dom.level);
    return CrowdStatusResult(
      displayLevel: next,
      baseSource: 'mixed',
      confidence: 'medium',
      reportCount: n,
      refreshUpdatedAt: next != displayBase,
    );
  }

  return _keepCurrent(
    current: displayBase,
    baseSource: 'owner',
    confidence: 'medium',
    reportCount: n,
  );
}

CrowdStatusResult computeCrowdStatus(CrowdStatusComputeParams params) {
  if (params.ownerJustReported && params.ownerLevel != null) {
    return CrowdStatusResult(
      displayLevel: params.ownerLevel!,
      baseSource: 'owner',
      confidence: 'high',
      reportCount: params.userLevels20.length,
      refreshUpdatedAt: true,
    );
  }

  var users = params.userLevels20;
  var current = params.currentDisplayLevel;
  var statusStartedAt = params.statusStartedAt;
  final sessionStart = params.businessSessionStart;

  if (sessionStart != null) {
    final anchor = statusStartedAt ?? params.lastUpdatedAt;
    if (anchor == null || anchor.isBefore(sessionStart)) {
      current = crowdLevelRelaxed;
      statusStartedAt = sessionStart;
    }
  }

  final owner = params.ownerLevel;

  if (users.isEmpty) {
    if (current != null) {
      return _keepCurrent(
        current: current,
        baseSource: owner == null ? 'user' : 'owner',
        confidence: owner == null ? 'medium' : 'high',
        reportCount: 0,
        refreshUpdatedAt:
            sessionStart != null &&
            (params.statusStartedAt == null ||
                params.statusStartedAt!.isBefore(sessionStart)),
      );
    }
    if (owner != null) {
      return CrowdStatusResult(
        displayLevel: owner,
        baseSource: 'owner',
        confidence: 'high',
        reportCount: 0,
        refreshUpdatedAt: true,
      );
    }
    return const CrowdStatusResult(
      displayLevel: crowdLevelRelaxed,
      baseSource: 'user',
      confidence: 'low',
      reportCount: 0,
    );
  }

  final inner = owner == null
      ? _computeUserOnly(current: current, users: users)
      : _computeOwnerAndUser(owner: owner, current: current, users: users);

  var display = inner.displayLevel;
  var refresh = inner.refreshUpdatedAt;

  if (current != null &&
      statusStartedAt != null &&
      display != current &&
      !params.ownerJustReported &&
      !isStrongUserSignal(users)) {
    final elapsed = params.now.difference(statusStartedAt);
    if (elapsed.inMinutes < 10) {
      display = current;
      refresh = false;
    }
  }

  return CrowdStatusResult(
    displayLevel: display,
    baseSource: inner.baseSource,
    confidence: inner.confidence,
    reportCount: inner.reportCount,
    refreshUpdatedAt: refresh,
  );
}

/// 추천 정렬용 freshness (0~100, 높을수록 최신)
int freshnessScore(int minutesSinceUpdate) {
  if (minutesSinceUpdate <= 15) return 100;
  if (minutesSinceUpdate <= 60) return 60;
  if (minutesSinceUpdate <= 24 * 60) return 20;
  return 5;
}
