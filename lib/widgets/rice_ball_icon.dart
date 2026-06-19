import 'package:flutter/material.dart';

class RiceBallIcon extends StatelessWidget {
  final double size;

  const RiceBallIcon({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.rice_bowl_outlined,
        size: size,
        color: const Color(0xFF5E8C4A),
      ),
    );
  }
}
