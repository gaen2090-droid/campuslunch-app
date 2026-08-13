// Android 12+ 시스템 스플래시 아이콘(windowSplashScreenAnimatedIcon) 재생성 v3.
// 새 브랜드 로고(물방울+반원, D:/캠런/로고_최종/brandlogo_real_real.png, 투명 배경)를
// 원형 마스크(288dp 캔버스 중 192dp 지름)에 맞춰 축소·중앙배치한다.
//
// v2(safeMargin=0.92, 로고 폭 기준)는 로고가 캔버스를 거의 꽉 채워 배치돼
// 원형 마스크 좌우 모서리가 잘리는 문제가 있었음. 실측 결과 로고 높이를
// 캔버스의 62%로 낮춰야 원형 마스크 안에 안전하게 들어가는 것을 확인했고,
// 6bd3b31 커밋에서 그 비율로 수정한 바 있음. v3는 그 비율(62%, 높이 기준)을
// 스크립트에 반영해 로고 원본이 바뀌어도 같은 안전 여백으로 재생성 가능하게 함.
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
  final srcBytes = File('D:/캠런/로고_최종/brandlogo_real_real.png').readAsBytesSync();
  final src = img.decodePng(srcBytes)!;

  // 로고 높이를 캔버스의 62%로 맞춘다(6bd3b31에서 실측 검증한 안전 비율).
  const heightRatio = 0.62;
  final aspect = src.width / src.height;

  for (final entry in sizes.entries) {
    final dir = entry.key;
    final canvasSize = entry.value;

    final targetH = (canvasSize * heightRatio).round();
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
