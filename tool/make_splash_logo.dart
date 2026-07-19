// 시스템 스플래시(Android 12+) 전용 로고 생성.
// 주의: 이 파일은 splash_brand_logo라는 별도 리소스 이름으로 만든다 —
// ic_launcher(홈 화면 앱 아이콘)와는 완전히 무관하며, 앱 아이콘에는
// 어떤 영향도 주지 않는다.
import 'dart:io';
import 'package:image/image.dart' as img;

const sizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

void main() {
  const resDir = 'android/app/src/main/res';
  final srcBytes = File('D:/캠런/로고_최종/systemsplash_logo.png').readAsBytesSync();
  final src = img.decodePng(srcBytes)!;

  // 소스(1024x1024) 안에서 실제 로고 콘텐츠의 bounding box: x[7,1017] y[283,740]
  const cropX = 7, cropY = 283, cropW = 1010, cropH = 457;
  final cropped = img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);

  // 사용자가 준 예시 사진 기준 로고 폭 비율 ≈ 58.6% (화면 폭 대비).
  // 정사각형 캔버스에서 동일 비율로 배치.
  const targetWidthRatio = 0.586;

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
