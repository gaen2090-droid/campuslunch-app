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

List<int> dedupeUserReportLevels(
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
    final createdAt = DateTime.parse(report['created_at'] as String).toLocal();
    if (createdAt.isBefore(effectiveSince)) continue;

    final key = _reportUserKey(report);
    if (key == null) continue;

    final existing = latestByUser[key];
    if (existing == null) {
      latestByUser[key] = report;
      continue;
    }
    final existingAt =
        DateTime.parse(existing['created_at'] as String).toLocal();
    if (createdAt.isAfter(existingAt)) {
      latestByUser[key] = report;
    }
  }

  return latestByUser.values.map(_reportLevel).toList();
}

int? latestOwnerLevel(List<Map<String, dynamic>> reports) {
  Map<String, dynamic>? latest;
  for (final report in reports) {
    if ((report['source'] as String?) != 'owner') continue;
    if (latest == null) {
      latest = report;
      continue;
    }
    final createdAt = DateTime.parse(report['created_at'] as String).toLocal();
    final latestAt =
        DateTime.parse(latest['created_at'] as String).toLocal();
    if (createdAt.isAfter(latestAt)) latest = report;
  }
  return latest == null ? null : _reportLevel(latest);
}

CrowdStatusResult computeStatusFromReports({
  required List<Map<String, dynamic>> reports,
  Map<String, dynamic>? existingStatus,
  DateTime? now,
  bool ownerJustReported = false,
  DateTime? businessSessionStart,
}) {
  final at = now ?? DateTime.now();
  final user20 = dedupeUserReportLevels(
    reports,
    const Duration(minutes: 20),
    at,
    since: businessSessionStart,
  );

  int? currentDisplay;
  DateTime? statusStartedAt;
  DateTime? lastUpdatedAt;
  if (existingStatus != null) {
    currentDisplay = parseDisplayLevel(existingStatus['display_level']);
    final started = existingStatus['status_started_at'] as String?;
    if (started != null) {
      statusStartedAt = DateTime.parse(started).toLocal();
    }
    final updated = existingStatus['updated_at'] as String?;
    if (updated != null) {
      lastUpdatedAt = DateTime.parse(updated).toLocal();
    }
  }

  return computeCrowdStatus(
    CrowdStatusComputeParams(
      ownerLevel: latestOwnerLevel(reports),
      userLevels20: user20,
      currentDisplayLevel: currentDisplay,
      statusStartedAt: statusStartedAt,
      lastUpdatedAt: lastUpdatedAt,
      businessSessionStart: businessSessionStart,
      now: at,
      ownerJustReported: ownerJustReported,
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
  final counts = <int, int>{1: 0, 2: 0, 3: 0};
  for (final level in levels) {
    counts[level] = (counts[level] ?? 0) + 1;
  }
  return counts;
}
