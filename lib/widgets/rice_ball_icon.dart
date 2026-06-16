import 'package:flutter/material.dart';

class RiceBallIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const RiceBallIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '\u{1F359}',
      style: TextStyle(fontSize: size, color: color, height: 1),
    );
  }
}
