import 'dart:math' as math;

/// 겹침 판정 대상 매장 마커. [priority]가 클수록 겹칠 때 우선 살아남는다.
class OverlapCandidate {
  final String id;
  final double latitude;
  final double longitude;
  final int priority;

  const OverlapCandidate({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.priority = 0,
  });
}

/// 화면 픽셀 거리 기준 그리디 마커 중복 제거.
///
/// 지도 축소로 마커 아이콘이 화면상 겹치면, 우선순위가 높은 마커부터 하나씩 자리를
/// 확정하고 그 아이콘 반경 안에 들어오는 나머지는 등록하지 않는다(네이버부동산 지도처럼
/// "겹치는 자리엔 하나만" 노출). 그룹 대표 좌표나 개수 배지는 만들지 않는다 — 살아남은
/// 마커는 원래 좌표·정체성을 그대로 유지한다.
abstract final class MarkerOverlap {
  /// [iconRadiusPixels]: 마커 아이콘 반경(px). 이 값의 2배(지름) 안에 두 마커가
  /// 들어오면 겹친 것으로 보고 하나만 남긴다.
  static List<String> resolveVisibleIds({
    required List<OverlapCandidate> candidates,
    required int zoomLevel,
    required double iconRadiusPixels,
  }) {
    if (candidates.isEmpty) return const [];

    final sorted = [...candidates]
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final degPerPixel = _degreesPerPixel(zoomLevel);
    final minSeparationDeg = iconRadiusPixels * 2 * degPerPixel;
    final minSeparationDegSq = minSeparationDeg * minSeparationDeg;

    final placed = <OverlapCandidate>[];
    final visible = <String>[];

    for (final candidate in sorted) {
      var overlaps = false;
      for (final p in placed) {
        final dLat = candidate.latitude - p.latitude;
        final dLng = candidate.longitude - p.longitude;
        final distSq = dLat * dLat + dLng * dLng;
        if (distSq < minSeparationDegSq) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        placed.add(candidate);
        visible.add(candidate.id);
      }
    }

    return visible;
  }

  /// Web Mercator 근사 (도/픽셀). 타일 256px, 줌 0 기준 — 카카오 Vector Map SDK
  /// zoomLevel은 레벨↑=확대(구글맵 방식).
  static double _degreesPerPixel(int zoomLevel) {
    final worldPx = 256.0 * math.pow(2, zoomLevel);
    return 360.0 / worldPx;
  }
}
