import 'dart:math' as math;

/// 클러스터링 대상 좌표 + 원본 id (Restaurant.id 등)
class ClusterInput {
  final String id;
  final double latitude;
  final double longitude;

  const ClusterInput({
    required this.id,
    required this.latitude,
    required this.longitude,
  });
}

/// 그리드 클러스터 결과. [ids].length == 1이면 단일 매장(클러스터 아님).
class ClusterGroup {
  final double latitude;
  final double longitude;
  final List<String> ids;

  const ClusterGroup({
    required this.latitude,
    required this.longitude,
    required this.ids,
  });

  bool get isSingle => ids.length == 1;
  int get count => ids.length;
}

/// 화면 픽셀 반경 기준 그리드 클러스터링 (Mercator 근사).
///
/// 카카오 Vector Map SDK의 zoomLevel은 레벨↑=확대(구글맵 방식, 대략 0~21).
/// 셀 크기(도 단위)는 줌 레벨이 낮을수록(축소될수록) 커진다.
abstract final class MarkerClustering {
  /// 항상 이 id 집합은 클러스터로 묶지 않고 개별 그룹으로 분리(선택된 매장 등).
  static List<ClusterGroup> cluster({
    required List<ClusterInput> points,
    required int zoomLevel,
    double cellPixelRadius = 70,
    Set<String> alwaysIndividual = const {},
  }) {
    if (points.isEmpty) return const [];

    final degPerPixel = _degreesPerPixel(zoomLevel);
    final cellSizeDeg = cellPixelRadius * 2 * degPerPixel;
    if (cellSizeDeg <= 0) {
      return points
          .map((p) => ClusterGroup(
                latitude: p.latitude,
                longitude: p.longitude,
                ids: [p.id],
              ))
          .toList();
    }

    final forced = <ClusterInput>[];
    final groupable = <ClusterInput>[];
    for (final p in points) {
      if (alwaysIndividual.contains(p.id)) {
        forced.add(p);
      } else {
        groupable.add(p);
      }
    }

    final cells = <String, List<ClusterInput>>{};
    for (final p in groupable) {
      final cellX = (p.longitude / cellSizeDeg).floor();
      final cellY = (p.latitude / cellSizeDeg).floor();
      cells.putIfAbsent('$cellX:$cellY', () => []).add(p);
    }

    final result = <ClusterGroup>[];
    for (final entry in cells.values) {
      if (entry.length == 1) {
        final p = entry.first;
        result.add(ClusterGroup(
          latitude: p.latitude,
          longitude: p.longitude,
          ids: [p.id],
        ));
        continue;
      }
      var sumLat = 0.0;
      var sumLng = 0.0;
      for (final p in entry) {
        sumLat += p.latitude;
        sumLng += p.longitude;
      }
      result.add(ClusterGroup(
        latitude: sumLat / entry.length,
        longitude: sumLng / entry.length,
        ids: entry.map((p) => p.id).toList(),
      ));
    }

    for (final p in forced) {
      result.add(ClusterGroup(
        latitude: p.latitude,
        longitude: p.longitude,
        ids: [p.id],
      ));
    }

    return result;
  }

  /// Web Mercator 기준 위도 40°N 부근 근사 (도/픽셀). 타일 256px, 줌 0 기준.
  static double _degreesPerPixel(int zoomLevel) {
    final worldPx = 256.0 * math.pow(2, zoomLevel);
    return 360.0 / worldPx;
  }
}
