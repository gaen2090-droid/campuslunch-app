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
          color: const Color(0xFF5E8C4A),
        ),
      ),
    );
  }
}

/// 스탬프 적립 화면 전용 — 브랜드 로고 교체와 무관하게 기존 주먹밥 캐릭터 유지.
class StampRiceBallIcon extends StatelessWidget {
  final double size;

  const StampRiceBallIcon({super.key, this.size = 22});

  static const assetPath = 'assets/images/rice_ball.png';

  @override
  Widget build(BuildContext context) {
    final cachePx = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 256);
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: cachePx,
      cacheHeight: cachePx,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(
        Icons.rice_bowl_outlined,
        size: size,
        color: const Color(0xFF5E8C4A),
      ),
    );
  }
}
