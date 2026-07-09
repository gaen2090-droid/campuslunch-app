import '../models/restaurant.dart';

int availablePopularScore(Restaurant r, bool useAlgorithmRanking) =>
    useAlgorithmRanking
        ? (r.popularityScore > 0 ? r.popularityScore : r.totalReports)
        : (r.manualRank > 0 ? -r.manualRank : -9999);

int availableStatusPriority(String status) {
  switch (status) {
    case '여유로움':
      return 0;
    case '약간혼잡':
      return 1;
    default:
      return 9;
  }
}

/// 바로 입장 가능: 1시간 단위 그룹 → 그룹 내 여유로움 우선 → 최신순 → 인기순
List<Restaurant> sortAvailableRestaurants(
  List<Restaurant> available,
  bool useAlgorithmRanking,
) {
  final list = List<Restaurant>.from(available);
  list.sort((a, b) {
    final aGroup = a.updated ~/ 60;
    final bGroup = b.updated ~/ 60;
    if (aGroup != bGroup) return aGroup.compareTo(bGroup);

    final statusDiff =
        availableStatusPriority(a.status) - availableStatusPriority(b.status);
    if (statusDiff != 0) return statusDiff;

    final updatedDiff = a.updated.compareTo(b.updated);
    if (updatedDiff != 0) return updatedDiff;

    return availablePopularScore(b, useAlgorithmRanking)
        .compareTo(availablePopularScore(a, useAlgorithmRanking));
  });
  return list;
}

List<Restaurant> filterAvailableRestaurants(List<Restaurant> restaurants) =>
    restaurants
        .where((r) => r.status == '여유로움' || r.status == '약간혼잡')
        .toList();

/// 추천 배너 = 바로 입장 가능 리스트 1위
Restaurant? pickRecommendedRestaurant(
  List<Restaurant> restaurants,
  bool useAlgorithmRanking,
) {
  final sorted = sortAvailableRestaurants(
    filterAvailableRestaurants(restaurants),
    useAlgorithmRanking,
  );
  return sorted.isEmpty ? null : sorted.first;
}

class AvailableSection {
  final Restaurant? recommended;
  final List<Restaurant> cards;

  const AvailableSection({required this.recommended, required this.cards});
}

AvailableSection buildAvailableSection(
  List<Restaurant> filtered,
  bool useAlgorithmRanking,
) {
  final available = filterAvailableRestaurants(filtered);

  // 추천 배너: 여유로움 10분 이내만 대상 → 없으면 숨김
  // 후보군 내: 최신순 → 인기순
  int Function(Restaurant, Restaurant) recSort(bool useAlgo) =>
      (a, b) {
        final ud = a.updated.compareTo(b.updated);
        if (ud != 0) return ud;
        return availablePopularScore(b, useAlgo)
            .compareTo(availablePopularScore(a, useAlgo));
      };

  final relaxedRecent = available
      .where((r) =>
          r.status == '여유로움' &&
          r.hasCrowdUpdate &&
          r.updatedAt != null &&
          DateTime.now().difference(r.updatedAt!).inMinutes <= 10)
      .toList()
    ..sort(recSort(useAlgorithmRanking));

  final recommended = relaxedRecent.isNotEmpty ? relaxedRecent.first : null;

  final sorted = sortAvailableRestaurants(available, useAlgorithmRanking);
  return AvailableSection(
    recommended: recommended,
    cards: recommended == null
        ? sorted
        : sorted.where((r) => r.id != recommended.id).toList(),
  );
}
