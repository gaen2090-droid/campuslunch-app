// ignore_for_file: avoid_print
/// .env → iOS Secrets.xcconfig / Android local.properties 동기화
///   dart run tool/sync_env_to_native.dart
import 'dart:io';

Future<void> main() async {
  final env = await _readEnv('.env');
  final mapsKey = env['GOOGLE_MAPS_API_KEY'] ?? '';
  if (mapsKey.isEmpty) {
    stderr.writeln('`.env`에 GOOGLE_MAPS_API_KEY가 없습니다.');
    exit(1);
  }

  // iOS
  final iosSecrets = File('ios/Flutter/Secrets.xcconfig');
  await iosSecrets.writeAsString('''
// 자동 생성 — Git 커밋 금지 (tool/sync_env_to_native.dart)
GOOGLE_MAPS_API_KEY=$mapsKey
''');
  print('Wrote ${iosSecrets.path}');

  // Android
  final localProps = File('android/local.properties');
  final lines = localProps.existsSync()
      ? await localProps.readAsLines()
      : <String>[];
  final out = <String>[];
  var found = false;
  for (final line in lines) {
    if (line.startsWith('GOOGLE_MAPS_API_KEY=')) {
      out.add('GOOGLE_MAPS_API_KEY=$mapsKey');
      found = true;
    } else {
      out.add(line);
    }
  }
  if (!found) out.add('GOOGLE_MAPS_API_KEY=$mapsKey');
  await localProps.writeAsString('${out.join('\n')}\n');
  print('Updated ${localProps.path}');
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
