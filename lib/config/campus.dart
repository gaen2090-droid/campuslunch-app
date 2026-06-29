/// 중앙대학교 흑석캠퍼스 (지도 기본 중심)
class Campus {
  static const double centerLat = 37.50699;
  static const double centerLng = 126.95707;
  static const String searchBias = '중앙대학교';

  /// 캠퍼스 주변 좌표 필터 (잘못된 DB 좌표가 bounds를 깨는 것 방지)
  static const double _latRadius = 0.012;
  static const double _lngRadius = 0.015;

  static bool containsLatLng(double lat, double lng) {
    return (lat - centerLat).abs() <= _latRadius &&
        (lng - centerLng).abs() <= _lngRadius;
  }
}
