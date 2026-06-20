import 'package:flutter/material.dart';

/// Google Maps 기본 핀과 같은 통짜 물방울 실루엣 (원형 머리 + 꼬리 X)
class MapPinPainter extends CustomPainter {
  /// 너비 대비 높이 (Google Maps 기본 핀 비율)
  static const aspectRatio = 1.36;

  final Color fillColor;
  final double borderWidth;
  final int shadowAlpha;
  final double shadowBlur;

  const MapPinPainter({
    required this.fillColor,
    this.borderWidth = 2.0,
    this.shadowAlpha = 20,
    this.shadowBlur = 6.0,
  });

  static Path pinPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final tipY = h - w * 0.02;

    // 아래 뾰족한 점 → 좌우 볼록 → 위 둥근 돔 (한 덩어리 곡선)
    return Path()
      ..moveTo(cx, tipY)
      ..cubicTo(
        cx - w * 0.10,
        tipY - h * 0.14,
        cx - w * 0.50,
        tipY - h * 0.50,
        cx - w * 0.47,
        h * 0.30,
      )
      ..cubicTo(
        cx - w * 0.44,
        h * 0.06,
        cx - w * 0.20,
        h * 0.01,
        cx,
        h * 0.01,
      )
      ..cubicTo(
        cx + w * 0.20,
        h * 0.01,
        cx + w * 0.44,
        h * 0.06,
        cx + w * 0.47,
        h * 0.30,
      )
      ..cubicTo(
        cx + w * 0.50,
        tipY - h * 0.50,
        cx + w * 0.10,
        tipY - h * 0.14,
        cx,
        tipY,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = pinPath(size);

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
  }

  @override
  bool shouldRepaint(MapPinPainter old) =>
      fillColor != old.fillColor ||
      borderWidth != old.borderWidth ||
      shadowAlpha != old.shadowAlpha ||
      shadowBlur != old.shadowBlur;
}
