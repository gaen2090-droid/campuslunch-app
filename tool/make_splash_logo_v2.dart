// Android 12+ 시스템 스플래시 아이콘(windowSplashScreenAnimatedIcon) 재생성.
// 새 브랜드 로고(물방울+반원, D:/캠런/로고_최종/brandlogo_real.png, 투명 배경)를
// 원형 마스크(288dp 캔버스 중 192dp 지름)에 맞춰 축소·중앙배치한다.
// 이전 make_splash_logo.dart는 가로로 긴 텍스트 워드마크용이라 이 로고엔 안 맞음.
import 'dart:io';
import 'package:image/image.dart' as img;

const sizes = {
  'mipmap-mdpi': 288,
  'mipmap-hdpi': 432,
  'mipmap-xhdpi': 576,
  'mipmap-xxhdpi': 864,
  'mipmap-xxxhdpi': 1152,
};

void main() {
  const resDir = 'android/app/src/main/res';
  final srcBytes = File('D:/캠런/로고_최종/brandlogo_real.png').readAsBytesSync();
  final src = img.decodePng(srcBytes)!;

  // 마스크 지름은 캔버스의 192/288 ≈ 66.7%. 로고 폭을 마스크 지름의 92%로 잡아
  // 원형 경계에 딱 붙지 않도록 여유를 둔다(대각선 방향 클리핑 방지).
  const maskDiameterRatio = 192 / 288;
  const safeMargin = 0.92;
  final aspect = src.width / src.height;

  for (final entry in sizes.entries) {
    final dir = entry.key;
    final canvasSize = entry.value;
    final maskDiameter = canvasSize * maskDiameterRatio;

    // 세로가 더 긴 로고이므로 높이 기준으로 맞추고 폭을 비율로 계산.
    final targetH = (maskDiameter * safeMargin).round();
    final targetW = (targetH * aspect).round();

    final resizedLogo = img.copyResize(
      src,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.average,
    );

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
