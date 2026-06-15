import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/restaurant.dart';

/// 혼잡도 → Google Maps 마커 색 (기존 statusMetaMap과 동일 계열)
double markerHueForStatus(String status) {
  switch (status) {
    case '여유로움':
      return BitmapDescriptor.hueGreen;
    case '약간혼잡':
      return BitmapDescriptor.hueOrange;
    case '자리없음':
      return BitmapDescriptor.hueRed;
    case '영업안함':
      // 실제 지도는 MapMarkerIcons.closed() 사용 (회색)
      return BitmapDescriptor.hueAzure;
    default:
      return BitmapDescriptor.hueAzure;
  }
}

int markerColorForStatus(String status) {
  final meta = statusMetaMap[status];
  return meta?.color ?? 0xFF9CA3AF;
}
