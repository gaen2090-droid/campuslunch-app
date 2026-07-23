// 실제 폰 화면(예: 1080x2400)에 시스템 스플래시 아이콘이 어느 정도
// 크기로 보이는지 재현하는 스크립트.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // 대표적인 폰 화면 픽셀 크기 (약 420dpi, xxhdpi 근사).
  const screenW = 1080;
  const screenH = 2400;

  final logoBytes = File('android/app/src/main/res/mipmap-xxhdpi/splash_brand_logo.png')
      .readAsBytesSync();
  final logo = img.decodePng(logoBytes)!; // 864x864 캔버스 (288dp * 3)

  final screen = img.Image(width: screenW, height: screenH, numChannels: 4);
  img.fill(screen, color: img.ColorRgba8(255, 255, 255, 255));

  final dstX = ((screenW - logo.width) / 2).round();
  final dstY = ((screenH - logo.height) / 2).round();
  img.compositeImage(screen, logo, dstX: dstX, dstY: dstY);

  // 192dp 원형 마스크(실제로 화면에 보이는 유일한 영역) 파란 원으로 표시.
  const maskDiameterRatio = 192 / 288;
  final maskDiameter = logo.width * maskDiameterRatio;
  final centerX = dstX + logo.width / 2;
  final centerY = dstY + logo.height / 2;
  for (final r in [
    (maskDiameter / 2).round(),
    (maskDiameter / 2).round() - 1,
    (maskDiameter / 2).round() - 2,
    (maskDiameter / 2).round() - 3,
  ]) {
    img.drawCircle(
      screen,
      x: centerX.round(),
      y: centerY.round(),
      radius: r,
      color: img.ColorRgba8(0, 100, 255, 255),
    );
  }

  File('tool/phone_preview.png').writeAsBytesSync(img.encodePng(screen));
  print('wrote tool/phone_preview.png (screen ${screenW}x$screenH, logo canvas ${logo.width}x${logo.height})');
}
