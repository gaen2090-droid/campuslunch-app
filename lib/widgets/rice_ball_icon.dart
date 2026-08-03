import 'package:flutter/material.dart';

import '../utils/map_pin_painter.dart';

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

/// 스탬프 적립 화면 전용 아이콘 — 지도 '제보필요' 마커와 같은 별 모양.
/// 배지 원은 호출부 Container가 이미 그리므로 별만 그림.
class StampRiceBallIcon extends StatelessWidget {
  final double size;
  final Color color;

  const StampRiceBallIcon({super.key, this.size = 22, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: StarOnlyPainter(color: color),
      ),
    );
  }
}
