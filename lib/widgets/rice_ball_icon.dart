import 'package:flutter/material.dart';

class RiceBallIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const RiceBallIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    if (color == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      child: image,
    );
  }
}
