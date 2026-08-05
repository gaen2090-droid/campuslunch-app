// 일회성 유틸: 알림 전용 아이콘 생성 (흰 배경 제거 + 여백 크롭 + 흰색 실루엣 + 투명 배경)
// 실행: dart run tool/gen_notification_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const sizes = <String, int>{
  'mipmap-mdpi': 24,
  'mipmap-hdpi': 36,
  'mipmap-xhdpi': 48,
  'mipmap-xxhdpi': 72,
  'mipmap-xxxhdpi': 96,
};

bool isBackground(img.Pixel p) {
  // 소스가 불투명 흰 배경이므로 밝은 흰색 계열을 배경으로 간주
  return p.r > 235 && p.g > 235 && p.b > 235;
}

void main() {
  final src = img.decodePng(
    File('assets/icon/app_icon_source.png').readAsBytesSync(),
  )!;

  // 1. 로고(흰 배경이 아닌 픽셀)의 bounding box 찾기
  int minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      if (!isBackground(src.getPixel(x, y))) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  final cropped = img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
  print('cropped: ${cropped.width}x${cropped.height} (from ${src.width}x${src.height})');

  for (final entry in sizes.entries) {
    final dirName = entry.key;
    final size = entry.value;
    final resized = img.copyResize(
      cropped,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );

    // Android 알림 small icon: 흰색 실루엣 + 투명 배경 (검정 배경은 시스템이 잘못 렌더링함)
    final out = img.Image(width: size, height: size, numChannels: 4);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);
        if (!isBackground(p)) {
          out.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
        } else {
          out.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }

    final dir = Directory('android/app/src/main/res/$dirName');
    dir.createSync(recursive: true);
    final outFile = File('${dir.path}/ic_stat_notify.png');
    outFile.writeAsBytesSync(img.encodePng(out));
    print('wrote ${outFile.path} (${size}x$size)');
  }
}
