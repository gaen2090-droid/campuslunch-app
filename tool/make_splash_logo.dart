// 시스템 스플래시(Android 12+) 전용 로고 생성.
// 주의: 이 파일은 splash_brand_logo라는 별도 리소스 이름으로 만든다 —
// ic_launcher(홈 화면 앱 아이콘)와는 완전히 무관하며, 앱 아이콘에는
// 어떤 영향도 주지 않는다.
import 'dart:io';
import 'package:image/image.dart' as img;

// Android 12+ 시스템 스플래시 아이콘(배경 없음, windowSplashScreenIconBackgroundColor
// transparent)은 288dp 캔버스에 192dp 원형 마스킹으로 렌더링된다
// (https://developer.android.com/develop/ui/views/launch/splash-screen).
// 기준 단위를 192dp로 잡았던 이전 버전은 캔버스(288dp)보다 작아
// 시스템이 확대(upscale)하며 화질이 흐려졌음 — 288dp 기준으로 수정.
const sizes = {
  'mipmap-mdpi': 288,
  'mipmap-hdpi': 432,
  'mipmap-xhdpi': 576,
  'mipmap-xxhdpi': 864,
  'mipmap-xxxhdpi': 1152,
};

void main() {
  const resDir = 'android/app/src/main/res';
  // 로고만 크롭된 고해상도 소스(2000x428) — 세로 해상도 부족으로 흐릿했던
  // 이전 splashlogo_final.png(1024x1024 전체 캔버스에서 크롭, 세로 193px) 문제 해결.
  final srcBytes = File('D:/캠런/로고_최종/splashlogo_big.png').readAsBytesSync();
  final src = img.decodePng(srcBytes)!;

  // 소스(2000x428) 안에서 실제 로고 콘텐츠의 bounding box: x[7,1989] y[8,383]
  const cropX = 7, cropY = 8, cropW = 1983, cropH = 376;
  final cropped = img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);

  // 192dp 원형 마스크 안전 영역(95% 여유) 기준 최대치로 확대.
  const targetWidthRatio = 0.622;

  for (final entry in sizes.entries) {
    final dir = entry.key;
    final canvasSize = entry.value;

    final targetW = (canvasSize * targetWidthRatio).round();
    final targetH = (targetW * cropH / cropW).round();
    final resizedLogo = img.copyResize(cropped, width: targetW, height: targetH);

    final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

    final offsetX = ((canvasSize - targetW) / 2).round();
    final offsetY = ((canvasSize - targetH) / 2).round();
    img.compositeImage(canvas, resizedLogo, dstX: offsetX, dstY: offsetY);

    final outPath = '$resDir/$dir/splash_brand_logo.png';
    File(outPath).writeAsBytesSync(img.encodePng(canvas));
    print('wrote $outPath ($canvasSize x $canvasSize, logo ${targetW}x$targetH)');
  }
}
