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

/// 붐비는 매장(자리없음/웨이팅많음) 최신순 그룹 — 0이 가장 우선
/// 자리없음 ≤15 → 자리없음 16~30 → 웨이팅 ≤15 → 웨이팅 16~30 → 자리없음 31+ → 웨이팅 31+
int busyLatestGroup(Restaurant r) {
  final isFull = r.status == '자리없음';
  final u = r.updated;
  if (isFull && u <= 15) return 0;
  if (isFull && u <= 30) return 1;
  if (!isFull && u <= 15) return 2;
  if (!isFull && u <= 30) return 3;
  if (isFull) return 4;
  return 5;
}

int availableSortStatusPriority(String status) => status == '여유로움' ? 0 : 1;

int busySortStatusPriority(String status) => status == '자리없음' ? 0 : 1;
