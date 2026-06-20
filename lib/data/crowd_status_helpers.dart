import 'crowd_level_mapper.dart';
import 'crowd_status_algorithm.dart';

int _reportLevel(Map<String, dynamic> report) {
  return crowdStatusToLevel(
    CrowdLevelMapper.fromDb(
      report['level'] as String,
      metadata: Map<String, dynamic>.from(report['metadata'] as Map? ?? {}),
    ),
  );
}

DateTime _reportAt(Map<String, dynamic> report) =>
    DateTime.parse(report['created_at'] as String).toLocal();

String? _reportUserKey(Map<String, dynamic> report) {
  final uid = report['user_id'] as String?;
  if (uid != null && uid.isNotEmpty) return uid;
  final meta = report['metadata'];
  if (meta is Map) {
    final metaUid = meta['user_id'] as String?;
    if (metaUid != null && metaUid.isNotEmpty) return metaUid;
  }
  return report['id'] as String?;
}

/// 계산 대상 유저 제보 — 유저당 최신 1건만, 레벨+시각 함께 보존
List<LevelReport> dedupeUserReports(
  List<Map<String, dynamic>> reports,
  Duration window,
  DateTime now, {
  DateTime? since,
}) {
  final cutoff = now.subtract(window);
  final effectiveSince = since != null && since.isAfter(cutoff) ? since : cutoff;
  final latestByUser = <String, Map<String, dynamic>>{};

  for (final report in reports) {
    if ((report['source'] as String?) != 'user') continue;
    final createdAt = _reportAt(report);
    if (createdAt.isBefore(effectiveSince)) continue;

    final key = _reportUserKey(report);
    if (key == null) continue;

    final existing = latestByUser[key];
    if (existing == null) {
      latestByUser[key] = report;
      continue;
    }
    if (createdAt.isAfter(_reportAt(existing))) {
      latestByUser[key] = report;
    }
  }

  return latestByUser.values
      .map((r) => LevelReport(level: _reportLevel(r), at: _reportAt(r)))
      .toList();
}

/// 호환용 — 레벨만 필요한 기존 호출부(통계 등)에서 사용
List<int> dedupeUserReportLevels(
  List<Map<String, dynamic>> reports,
  Duration window,
  DateTime now, {
  DateTime? since,
}) =>
    dedupeUserReports(reports, window, now, since: since)
        .map((r) => r.level)
        .toList();

LevelReport? latestOwnerReport(List<Map<String, dynamic>> reports) {
  Map<String, dynamic>? latest;
  for (final report in reports) {
    if ((report['source'] as String?) != 'owner') continue;
    if (latest == null || _reportAt(report).isAfter(_reportAt(latest))) {
      latest = report;
    }
  }
  return latest == null
      ? null
      : LevelReport(level: _reportLevel(latest), at: _reportAt(latest));
}

int? latestOwnerLevel(List<Map<String, dynamic>> reports) =>
    latestOwnerReport(reports)?.level;

CrowdStatusResult computeStatusFromReports({
  required List<Map<String, dynamic>> reports,
  Map<String, dynamic>? existingStatus,
  DateTime? now,
  DateTime? businessSessionStart,
}) {
  final at = now ?? DateTime.now();
  final userReports = dedupeUserReports(
    reports,
    const Duration(minutes: 20),
    at,
    since: businessSessionStart,
  );

  int? currentDisplay;
  if (existingStatus != null) {
    currentDisplay = parseDisplayLevel(existingStatus['display_level']);
  }

  return computeCrowdStatus(
    CrowdStatusComputeParams(
      ownerLatest: latestOwnerReport(reports),
      userReports: userReports,
      currentDisplayLevel: currentDisplay,
      now: at,
    ),
  );
}

int minutesSinceUpdated(Map<String, dynamic>? crowdStatusRow) {
  if (crowdStatusRow == null) return 0;
  final updated = crowdStatusRow['updated_at'] as String?;
  if (updated == null) return 0;
  return DateTime.now()
      .difference(DateTime.parse(updated).toLocal())
      .inMinutes;
}

String? crowdMetaString(Map<String, dynamic>? row, String key) {
  if (row == null) return null;
  final value = row[key];
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int countRecentUserReports(
  List<Map<String, dynamic>> reports, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return dedupeUserReportLevels(reports, const Duration(minutes: 20), at)
      .length;
}

Map<int, int> recentUserLevelCounts(
  List<Map<String, dynamic>> reports, {
  DateTime? now,
}) {
  final levels =
      dedupeUserReportLevels(reports, const Duration(minutes: 20), now ?? DateTime.now());
  final counts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
  for (final level in levels) {
    counts[level] = (counts[level] ?? 0) + 1;
  }
  return counts;
}
