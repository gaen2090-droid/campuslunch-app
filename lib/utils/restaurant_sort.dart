import '../models/restaurant.dart';

int popularityScore(Restaurant r, bool useAlgorithmRanking) =>
    useAlgorithmRanking
        ? (r.popularityScore > 0 ? r.popularityScore : r.totalReports)
        : (r.manualRank > 0 ? -r.manualRank : -9999);

/// 바로입장가능(여유로움/약간혼잡) 최신순 그룹 — 0이 가장 우선
/// 여유 ≤15 → 여유 16~30 → 약간혼잡 ≤15 → 약간혼잡 16~30 → 여유 31+ → 약간혼잡 31+
int availableLatestGroup(Restaurant r) {
  final isRelaxed = r.status == '여유로움';
  final u = r.updated;
  if (isRelaxed && u <= 15) return 0;
  if (isRelaxed && u <= 30) return 1;
  if (!isRelaxed && u <= 15) return 2;
  if (!isRelaxed && u <= 30) return 3;
  if (isRelaxed) return 4;
  return 5;
}

/// 붐비는 매장(자리없음) 최신순 그룹 — 0이 가장 우선
/// 자리없음 ≤15 → 자리없음 16~30 → 자리없음 31+
int busyLatestGroup(Restaurant r) {
  final u = r.updated;
  if (u <= 15) return 0;
  if (u <= 30) return 1;
  return 2;
}

int availableSortStatusPriority(String status) => status == '여유로움' ? 0 : 1;

int busySortStatusPriority(String status) => status == '자리없음' ? 0 : 1;
