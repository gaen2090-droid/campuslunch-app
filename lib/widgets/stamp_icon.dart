import 'package:flutter/material.dart';

class StampIcon extends StatelessWidget {
  final double size;
  final bool filled;

  const StampIcon({super.key, this.size = 22, this.filled = true});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    if (filled) return image;
    return Opacity(opacity: 0.35, child: image);
  }
}
