import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/rice_ball_icon.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 블러 장식 - 우측 상단
          Positioned(
            right: -80,
            top: 60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E6BA),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // 블러 장식 - 좌측 하단
          Positioned(
            left: -100,
            bottom: 100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF9ECA8B).withAlpha(180),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // 중앙 로고
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9ECA8B),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFC8E6BA),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: RiceBallIcon(size: 40),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '캠퍼스런치',
                  style: TextStyle(
                    fontFamily: 'OkDanDan',
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5E8C4A),
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '지금 어디가 여유로울까?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
