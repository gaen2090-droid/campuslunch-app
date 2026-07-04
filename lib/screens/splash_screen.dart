import 'package:flutter/material.dart';
import '../widgets/rice_ball_icon.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 다음 화면 전환 전에 로고 디코딩을 끝냄
      precacheImage(
        ResizeImage(
          const AssetImage(RiceBallIcon.assetPath),
          width: 120,
          height: 120,
        ),
        context,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SplashLogo(),
            SizedBox(height: 20),
            Text(
              '캠퍼스런치',
              style: TextStyle(
                fontFamily: 'OkDanDan',
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5E8C4A),
                letterSpacing: -1.0,
              ),
            ),
            SizedBox(height: 8),
            Text(
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
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
