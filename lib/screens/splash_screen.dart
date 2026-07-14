import 'package:flutter/material.dart';

import '../constants/brand_assets.dart';

/// 첫 화면 — 네이티브 런치와 동일한 풀스크린 합성 이미지 (흰 배경)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: _SplashFullImage(),
    );
  }
}

class _SplashFullImage extends StatelessWidget {
  const _SplashFullImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.splashScreenFull,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const _SplashFallback(),
    );
  }
}

class _SplashFallback extends StatelessWidget {
  const _SplashFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        BrandAssets.splashBrand,
        fit: BoxFit.contain,
      ),
    );
  }
}
