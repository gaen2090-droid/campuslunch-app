// ignore_for_file: avoid_print
/// Android App Links용 SHA-256 fingerprint 안내
///
///   dart run tool/print_app_link_sha256.dart
///
/// 출력된 값을 share-web/public/.well-known/assetlinks.json 에 넣고
/// campuslunch.shop (share-web Vercel)에 배포하세요.
import 'dart:io';

Future<void> main() async {
  print('Android App Links — SHA-256 fingerprint\n');
  print('릴리스 (Play Store / APK 서명 키):');
  print('  cd android && ./gradlew :app:signingReport');
  print('  → Variant: release 의 SHA-256 복사\n');
  print('디버그 (flutter run):');
  print('  keytool -list -v -keystore ~/.android/debug.keystore \\');
  print('    -alias androiddebugkey -storepass android -keypass android');
  print('  → SHA256 줄 → assetlinks.json 에 붙여넣기\n');
  print('파일: share-web/public/.well-known/assetlinks.json');
  print('호스트: campuslunch.shop → share-web Vercel 프로젝트에 연결');
  exit(0);
}
