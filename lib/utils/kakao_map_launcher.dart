import '../models/map_lat_lng.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openKakaoMapWalkingRoute({
  required MapLatLng origin,
  required MapLatLng destination,
}) async {
  final uri = Uri.parse(
    'kakaomap://route'
    '?sp=${origin.latitude},${origin.longitude}'
    '&ep=${destination.latitude},${destination.longitude}'
    '&by=FOOT',
  );
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  final webUri = Uri.parse(
    'https://map.kakao.com/link/to/'
    '${destination.latitude},${destination.longitude}',
  );
  return launchUrl(webUri, mode: LaunchMode.externalApplication);
}
