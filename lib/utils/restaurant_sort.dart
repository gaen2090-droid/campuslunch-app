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

/// 사장님 제보(상태 직접 입력, 또는 좌석 입력으로 가정된 상태)가 최신 제보인지.
bool isOwnerSourcedCrowd(Restaurant r) =>
    r.crowdBaseSource == 'owner' || r.isSeatDerived;

/// 이 시간 이내의 사장님 제보는 섹션 정렬과 무관하게 섹션 최상단에 둔다.
const Duration ownerReportPriorityWindow = Duration(minutes: 5);

/// [sorted] 목록에서 5분 이내 사장님 제보 매장을 맨 앞으로 올린다.
/// 앞으로 올라간 매장끼리는 최신순, 나머지는 기존 정렬 순서를 그대로 유지한다.
List<Restaurant> prioritizeFreshOwnerReports(
  List<Restaurant> sorted,
  DateTime now,
) {
  Duration elapsed(Restaurant r) => r.updatedAt != null
      ? now.difference(r.updatedAt!)
      : Duration(minutes: r.updated);

  final fresh = <MapEntry<int, Restaurant>>[];
  final rest = <Restaurant>[];
  for (var i = 0; i < sorted.length; i++) {
    final r = sorted[i];
    if (r.hasCrowdUpdate &&
        isOwnerSourcedCrowd(r) &&
        elapsed(r) <= ownerReportPriorityWindow) {
      fresh.add(MapEntry(i, r));
    } else {
      rest.add(r);
    }
  }
  if (fresh.isEmpty) return sorted;
  fresh.sort((a, b) {
    final d = elapsed(a.value).compareTo(elapsed(b.value));
    return d != 0 ? d : a.key.compareTo(b.key);
  });
  return [...fresh.map((e) => e.value), ...rest];
}

int availableSortStatusPriority(String status) => status == '여유로움' ? 0 : 1;

int busySortStatusPriority(String status) => status == '자리없음' ? 0 : 1;
