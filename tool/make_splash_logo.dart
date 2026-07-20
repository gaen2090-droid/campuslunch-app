// 시스템 스플래시(Android 12+) 전용 로고 생성.
// 주의: 이 파일은 splash_brand_logo라는 별도 리소스 이름으로 만든다 —
// ic_launcher(홈 화면 앱 아이콘)와는 완전히 무관하며, 앱 아이콘에는
// 어떤 영향도 주지 않는다.
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

double _sqrt(num x) => math.sqrt(x);

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
  // "CAM / LUN" 2행 배치 워드마크, 고해상도 원본(2003x1350). 정사각형에
  // 가까운 비율이라 원형 마스크에 유리하고, 소스 자체가 커서(1945x1339)
  // xxxhdpi 목표 폭(~580px)까지 다운스케일해도 디테일 손실이 거의 없음.
  // 콘텐츠 bounding box: x[25,1969] y[6,1344].
  final srcBytes = File('D:/캠런/로고_최종/splashlogo_big_final.png').readAsBytesSync();
  final src = img.decodePng(srcBytes)!;

  const cropX = 25, cropY = 6, cropW = 1945, cropH = 1339;
  final cropped = img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);

  // 워드마크 가로세로비가 매우 넓적(1983:194 ≈ 10.2:1)해서 단순 폭 비율이
  // 아니라 "192dp 원에 내접하는 직사각형" 대각선 제약으로 최대 크기를 구한다.
  // 마스크 지름 대비 192/288(288dp 캔버스 기준), 대각선 안전 여유 92%.
  const maskDiameterRatio = 192 / 288;
  const safeMargin = 0.92;
  final aspect = cropW / cropH;
  // diag^2 = w^2 + h^2, h = w/aspect → w = diag / sqrt(1 + 1/aspect^2)
  final diagFactor = 1 / (1 + 1 / (aspect * aspect));
  final widthFraction = (diagFactor > 0 ? _sqrt(diagFactor) : 0) * safeMargin;

  for (final entry in sizes.entries) {
    final dir = entry.key;
    final canvasSize = entry.value;
    final maskDiameter = canvasSize * maskDiameterRatio;

    final targetW = (maskDiameter * widthFraction).round();
    final targetH = (targetW * cropH / cropW).round();
    // package:image의 copyResize 기본 보간은 Interpolation.nearest —
    // 1983px→717px처럼 큰 폭으로 축소할 때 픽셀을 단순 샘플링해 건너뛰어
    // 곡선 획 가장자리가 계단처럼 깨지는 원인이었음. 다운스케일에 적합한
    // average(영역 평균)로 명시 지정해 앤티앨리어싱 적용.
    final resizedLogo = img.copyResize(
      cropped,
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
