import '../models/restaurant.dart';

/// 추천 배너 매장 구역 → 푸시 문구용 게이트명 (정문/중문/후문)
String gateLabelFromArea(String area) {
  if (area.contains('정문')) return '정문';
  if (area.contains('중문')) return '중문';
  if (area.contains('후문')) return '후문';
  if (area.contains('학교') || area.contains('학생')) return '학교';
  return '캠퍼스';
}

String gateLabelFromRestaurant(Restaurant restaurant) =>
    gateLabelFromArea(restaurant.area);
