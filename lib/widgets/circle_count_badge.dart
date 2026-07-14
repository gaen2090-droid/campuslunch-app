import 'package:flutter/material.dart';

/// 초록 원 안에 숫자를 표시하는 배지 (쿠폰함 등 보유 개수 표시용).
class CircleCountBadge extends StatelessWidget {
  final int count;
  final double size;

  const CircleCountBadge({super.key, required this.count, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF5E8C4A),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}
