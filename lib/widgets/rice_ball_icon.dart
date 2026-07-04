import 'package:flutter/material.dart';

class RiceBallIcon extends StatelessWidget {
  final double size;

  const RiceBallIcon({super.key, this.size = 22});

  static const assetPath = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    // 원본 1125px를 그대로 디코딩하면 스플래시에서 로고가 늦게/안 뜸
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
