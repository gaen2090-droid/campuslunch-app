import 'package:flutter/material.dart';

/// 카카오맵 기본 POI 핀과 비슷한 실루엣 (둥근 머리 + 짧은 꼬리 + 중앙 하이라이트)
class MapPinPainter extends CustomPainter {
  static const aspectRatio = 44 / 36;

  final Color fillColor;
  final double borderWidth;
  final int shadowAlpha;
  final double shadowBlur;
  final bool showInnerDot;

  const MapPinPainter({
    required this.fillColor,
    this.borderWidth = 1.5,
    this.shadowAlpha = 28,
    this.shadowBlur = 4.0,
    this.showInnerDot = true,
  });

  static Path pinPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final tipY = h - 0.5;
    final headRadius = w * 0.38;
    final headCy = headRadius + w * 0.07;

    return Path()
      ..moveTo(cx, tipY)
      ..cubicTo(
        cx - w * 0.05,
        h * 0.74,
        cx - headRadius,
        headCy + headRadius * 0.42,
        cx - headRadius,
        headCy,
      )
      ..arcToPoint(
        Offset(cx + headRadius, headCy),
        radius: Radius.circular(headRadius),
      )
      ..cubicTo(
        cx + headRadius,
        headCy + headRadius * 0.42,
        cx + w * 0.05,
        h * 0.74,
        cx,
        tipY,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = pinPath(size);
    final w = size.width;
    final headRadius = w * 0.38;
    final headCy = headRadius + w * 0.07;
    final cx = w / 2;

    canvas.drawShadow(
      path,
      Colors.black.withAlpha(shadowAlpha),
      shadowBlur,
      false,
    );
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round,
    );

    if (showInnerDot) {
      canvas.drawCircle(
        Offset(cx, headCy),
        w * 0.13,
        Paint()..color = Colors.white.withAlpha(230),
      );
    }
  }

  @override
  bool shouldRepaint(MapPinPainter old) =>
      fillColor != old.fillColor ||
      borderWidth != old.borderWidth ||
      shadowAlpha != old.shadowAlpha ||
      shadowBlur != old.shadowBlur ||
      showInnerDot != old.showInnerDot;
}
