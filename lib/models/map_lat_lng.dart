/// 지도 SDK에 의존하지 않는 위·경도 (카카오 x=경도, y=위도와 별개로 lat/lng 명명)
class MapLatLng {
  final double latitude;
  final double longitude;

  const MapLatLng(this.latitude, this.longitude);

  @override
  String toString() => 'MapLatLng($latitude, $longitude)';
}
