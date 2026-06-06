import '../data/crowd_status_algorithm.dart';
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

/// 바로 입장 가능: 여유로움 우선 → freshness → 인기순
List<Restaurant> sortAvailableRestaurants(
  List<Restaurant> available,
  bool useAlgorithmRanking,
) {
  final list = List<Restaurant>.from(available);
  list.sort((a, b) {
    final statusDiff =
        availableStatusPriority(a.status) - availableStatusPriority(b.status);
    if (statusDiff != 0) return statusDiff;

    final freshDiff = freshnessScore(b.updated) - freshnessScore(a.updated);
    if (freshDiff != 0) return freshDiff;

    final scoreDiff = availablePopularScore(b, useAlgorithmRanking)
        .compareTo(availablePopularScore(a, useAlgorithmRanking));
    if (scoreDiff != 0) return scoreDiff;
    return a.name.compareTo(b.name);
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
  final sorted = sortAvailableRestaurants(
    filterAvailableRestaurants(filtered),
    useAlgorithmRanking,
  );
  if (sorted.isEmpty) {
    return const AvailableSection(recommended: null, cards: []);
  }
  final recommended = sorted.first;
  return AvailableSection(
    recommended: recommended,
    cards: sorted.skip(1).toList(),
  );
}
