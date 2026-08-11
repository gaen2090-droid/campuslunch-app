import 'package:flutter/material.dart';

class RiceBallIcon extends StatelessWidget {
  final double? size;

  const RiceBallIcon({super.key, this.size = 22});

  static const assetPath = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    if (size != null) {
      return _buildImage(context, assetPath, size!);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return _buildImage(context, assetPath, side.isFinite ? side : 48);
      },
    );
  }

  static Widget _buildImage(BuildContext context, String path, double renderSize) {
    // 원본을 그대로 디코딩하면 스플래시에서 로고가 늦게/안 뜸
    final cachePx = (renderSize * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 512);
    return ClipRRect(
      borderRadius: BorderRadius.circular(renderSize * 0.22),
      child: Image.asset(
        path,
        width: renderSize,
        height: renderSize,
        fit: BoxFit.cover,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Icon(
          Icons.rice_bowl_outlined,
          size: renderSize,
          color: const Color(0xFF000000),
        ),
      ),
    );
  }
}

/// 스플래시·런처와 동일한 앱 아이콘 (UI용 logo.png 와 별도)
class AppLauncherIcon extends StatelessWidget {
  final double size;

  const AppLauncherIcon({super.key, this.size = 72});

  static const assetPath = 'assets/icon/app_icon_source.png';

  @override
  Widget build(BuildContext context) {
    final cachePx = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 512);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Icon(
          Icons.rice_bowl_outlined,
          size: size,
          color: const Color(0xFF000000),
        ),
      ),
    );
  }
}

/// 스탬프 적립 화면 전용 아이콘. 원 배경은 코드로 직접 그리고(해상도 무관하게
/// 완전한 안티앨리어싱), 그 위에 흰색 로고 실루엣(stamp_mark.png, 투명 배경)만
/// 이미지로 얹는다 — 래스터 이미지로 원까지 그리면 작은 크기에서 계단현상이
/// 생기던 문제를 피한다.
class StampRiceBallIcon extends StatelessWidget {
  final double size;
  /// 로고 실제 높이(px)를 직접 지정. 미지정 시 size*0.56(원 지름의 56%).
  /// 호출부마다 원 크기가 달라 같은 비율이면 큰 원(예: 마이페이지 오늘의
  /// 스탬프)에서 로고가 과도하게 커 보이므로, 원 크기와 무관하게 시각적
  /// 로고 크기를 다른 화면과 맞추고 싶을 때 사용한다.
  final double? markHeight;

  const StampRiceBallIcon({super.key, this.size = 22, this.markHeight});

  static const assetPath = 'assets/images/stamp_mark.png';

  // stamp_mark.png 원본 비율(2021x2040) — width/height를 이 비율에 맞춰
  // 계산해서 BoxFit.contain 없이도 실제 픽셀이 눌리지 않도록 한다.
  static const _markAspect = 2021 / 2040;

  @override
  Widget build(BuildContext context) {
    final markHeight = this.markHeight ?? size * 0.56;
    final markWidth = markHeight * _markAspect;
    final cachePx = (markHeight * MediaQuery.devicePixelRatioOf(context) * 2)
        .round()
        .clamp(1, 1024);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Image.asset(
          assetPath,
          width: markWidth,
          height: markHeight,
          fit: BoxFit.contain,
          cacheHeight: cachePx,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            Icons.rice_bowl_outlined,
            size: markHeight,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
