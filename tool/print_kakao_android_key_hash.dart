// ignore_for_file: avoid_print
/// 이 PC의 Android 디버그 키 해시 출력 → 카카오 개발자 콘솔에 등록
///
///   /Users/dongha/develop/flutter/bin/dart run tool/print_kakao_android_key_hash.dart
///
/// developers.kakao.com → 앱 → 플랫폼 → Android → 키 해시에 붙여넣기
/// (팀원마다 다르면 각자 해시를 모두 등록)
import 'dart:io';

Future<void> main() async {
  if (!Platform.isMacOS && !Platform.isLinux) {
    print('Mac/Linux 터미널에서 keytool + openssl 로 해시를 구하세요.');
    print('docs/KAKAO_SUPABASE_SETUP.md 참고');
    exit(1);
  }

  final keystore = Platform.isMacOS
      ? '${Platform.environment['HOME']}/.android/debug.keystore'
      : '${Platform.environment['USERPROFILE']}\\.android\\debug.keystore';

  if (!File(keystore).existsSync()) {
    stderr.writeln('debug.keystore 없음: $keystore');
    stderr.writeln('한 번이라도 Android 빌드(flutter run) 후 다시 실행하세요.');
    exit(1);
  }

  final result = await Process.run(
    'bash',
    [
      '-c',
      'keytool -exportcert -alias androiddebugkey -keystore "$keystore" '
          '-storepass android -keypass android 2>/dev/null '
          '| openssl sha1 -binary | openssl base64',
    ],
  );

  final hash = (result.stdout as String).trim();
  if (hash.isEmpty || result.exitCode != 0) {
    stderr.writeln('키 해시 계산 실패: ${result.stderr}');
    exit(1);
  }

  print('=== Android 디버그 키 해시 (이 Mac/PC) ===');
  print(hash);
  print('');
  print('카카오 developers.kakao.com → 내 애플리케이션 → 앱 선택');
  print('→ [플랫폼] Android → 패키지 com.campuslunch.app');
  print('→ [키 해시]에 위 한 줄 추가 (기존 해시는 지우지 말고 줄바꿈으로 추가)');
  print('');
  print('등록 후 앱 삭제 → flutter run 으로 재설치 후 카카오 로그인 테스트');
}
