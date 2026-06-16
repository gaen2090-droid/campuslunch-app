// ignore_for_file: avoid_print
/// Android 키 해시 출력 → 카카오 개발자 콘솔 등록
///
/// 디버그 (flutter run / debug keystore):
///   dart run tool/print_kakao_android_key_hash.dart
///
/// 릴리스 APK (android/key.properties keystore):
///   dart run tool/print_kakao_android_key_hash.dart --release
///
/// Google OAuth SHA-1도 함께 출력 (Cloud Console Android 클라이언트 등록용)
import 'dart:io';

Future<String?> _kakaoHash({
  required String keystore,
  required String alias,
  required String storePass,
  required String keyPass,
}) async {
  if (!File(keystore).existsSync()) return null;
  final result = await Process.run(
    'bash',
    [
      '-c',
      'keytool -exportcert -alias "$alias" -keystore "$keystore" '
          '-storepass "$storePass" -keypass "$keyPass" 2>/dev/null '
          '| openssl sha1 -binary | openssl base64',
    ],
  );
  final hash = (result.stdout as String).trim();
  if (hash.isEmpty || result.exitCode != 0) return null;
  return hash;
}

Future<String?> _sha1({
  required String keystore,
  required String alias,
  required String storePass,
  required String keyPass,
}) async {
  if (!File(keystore).existsSync()) return null;
  final result = await Process.run(
    'bash',
    [
      '-c',
      'keytool -list -v -alias "$alias" -keystore "$keystore" '
          '-storepass "$storePass" -keypass "$keyPass" 2>/dev/null '
      r"| grep -i 'SHA1:' | head -1 | sed -E 's/.*SHA1:[[:space:]]*//'",
    ],
  );
  final sha = (result.stdout as String).trim();
  if (sha.isEmpty || result.exitCode != 0) return null;
  return sha;
}

Map<String, String> _readKeyProperties(File file) {
  final map = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i > 0) map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
  }
  return map;
}

Future<void> _printBlock({
  required String title,
  required String keystore,
  required String alias,
  required String storePass,
  required String keyPass,
}) async {
  print('=== $title ===');
  print('keystore: $keystore');
  if (!File(keystore).existsSync()) {
    print('(keystore 없음 — 건너뜀)\n');
    return;
  }
  final hash = await _kakaoHash(
    keystore: keystore,
    alias: alias,
    storePass: storePass,
    keyPass: keyPass,
  );
  final sha1 = await _sha1(
    keystore: keystore,
    alias: alias,
    storePass: storePass,
    keyPass: keyPass,
  );
  print('Kakao 키 해시: ${hash ?? "(계산 실패)"}');
  print('Google SHA-1:  ${sha1 ?? "(계산 실패)"}');
  print('');
}

Future<void> main(List<String> args) async {
  if (!Platform.isMacOS && !Platform.isLinux) {
    print('Mac/Linux 터미널에서 실행하세요. docs/KAKAO_SUPABASE_SETUP.md 참고');
    exit(1);
  }

  final home = Platform.environment['HOME'] ?? '';
  final debugKeystore = Platform.isMacOS
      ? '$home/.android/debug.keystore'
      : '${Platform.environment['USERPROFILE']}\\.android\\debug.keystore';

  final releaseOnly = args.contains('--release');
  final projectRoot = Directory.current.path.endsWith('tool')
      ? Directory.current.parent
      : Directory.current;
  final keyPropsFile = File('${projectRoot.path}/android/key.properties');

  print('패키지: com.campuslunch.app\n');

  if (!releaseOnly) {
    await _printBlock(
      title: 'Debug (flutter run / debug APK)',
      keystore: debugKeystore,
      alias: 'androiddebugkey',
      storePass: 'android',
      keyPass: 'android',
    );
  }

  if (keyPropsFile.existsSync()) {
    final props = _readKeyProperties(keyPropsFile);
    final storeFile = props['storeFile'];
    if (storeFile != null && storeFile.isNotEmpty) {
      final keystorePath = File('${projectRoot.path}/android/app/$storeFile');
      await _printBlock(
        title: 'Release (flutter build apk + key.properties)',
        keystore: keystorePath.path,
        alias: props['keyAlias'] ?? '',
        storePass: props['storePassword'] ?? '',
        keyPass: props['keyPassword'] ?? '',
      );
    } else {
      print('android/key.properties 에 storeFile 없음\n');
    }
  } else if (releaseOnly) {
    print('android/key.properties 없음.');
    print('릴리스 APK가 debug keystore로 서명됐다면 위 Debug 해시를 등록하세요.\n');
  } else {
    print(
      'android/key.properties 없음 → release APK도 debug keystore 서명.\n'
      'Debug 해시만 카카오/Google 콘솔에 등록하면 됩니다.\n',
    );
  }

  print('카카오: developers.kakao.com → Android → 키 해시 추가');
  print('Google: Cloud Console → Credentials → Android OAuth → SHA-1 추가');
  print('등록 후 APK 삭제 → 재설치 후 로그인 테스트');
}
