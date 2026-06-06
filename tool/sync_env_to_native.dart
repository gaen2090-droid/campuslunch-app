// ignore_for_file: avoid_print
/// .env → ios/Flutter/Secrets.xcconfig / android/keys.properties 동기화
///   dart run tool/sync_env_to_native.dart
import 'dart:io';

Future<void> main() async {
  final env = await _readEnv('.env');
  final mapsKey = env['GOOGLE_MAPS_API_KEY'] ?? '';
  final kakaoKey = env['KAKAO_NATIVE_APP_KEY'] ?? '';
  final googleWebClientId = env['GOOGLE_OAUTH_WEB_CLIENT_ID'] ?? '';
  final googleIosClientId = env['GOOGLE_OAUTH_IOS_CLIENT_ID'] ?? '';
  if (mapsKey.isEmpty) {
    stderr.writeln('`.env`에 GOOGLE_MAPS_API_KEY가 없습니다.');
    exit(1);
  }

  final googleReversedClientId = _reverseGoogleClientId(googleIosClientId);

  final iosSecrets = File('ios/Flutter/Secrets.xcconfig');
  await iosSecrets.writeAsString('''
// .env 와 동기화 (private repo — tool/sync_env_to_native.dart)
GOOGLE_MAPS_API_KEY=$mapsKey
KAKAO_NATIVE_APP_KEY=$kakaoKey
GOOGLE_OAUTH_IOS_CLIENT_ID=$googleIosClientId
GOOGLE_REVERSED_CLIENT_ID=$googleReversedClientId
''');
  print('Wrote ${iosSecrets.path}');

  final keysProps = File('android/keys.properties');
  await keysProps.writeAsString('''
# API 키 (팀 공용, private repo). Flutter SDK 경로는 local.properties(자동 생성) 사용.
GOOGLE_MAPS_API_KEY=$mapsKey
KAKAO_NATIVE_APP_KEY=$kakaoKey
GOOGLE_OAUTH_WEB_CLIENT_ID=$googleWebClientId
''');
  print('Wrote ${keysProps.path}');
}

String _reverseGoogleClientId(String clientId) {
  if (clientId.isEmpty) return '';
  return clientId.split('.').reversed.join('.');
}

Future<Map<String, String>> _readEnv(String path) async {
  final file = File(path);
  if (!await file.exists()) return {};
  final map = <String, String>{};
  for (final line in await file.readAsLines()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i <= 0) continue;
    map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
  }
  return map;
}
