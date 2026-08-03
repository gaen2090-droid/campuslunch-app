import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 카카오맵 기본 POI 핀과 비슷한 실루엣 (둥근 머리 + 짧은 꼬리 + 중앙 하이라이트)
class MapPinPainter extends CustomPainter {
  static const aspectRatio = 66 / 72;

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

  /// 스탬프 마커(원 반지름 ≈ 캔버스 폭의 0.42배, 48px 캔버스 기준)와 대가리 크기를
  /// 맞추기 위해 0.38보다 작게 잡음(72px 캔버스 기준 ≈ 20px 반지름).
  static const double headRadiusRatio = 0.28;

  static Path pinPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final tipY = h - 0.5;
    final headRadius = w * headRadiusRatio;
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
    final headRadius = w * headRadiusRatio;
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

/// '제보필요' 마커 — 핀이 아닌 동그란 스탬프 배지 (검정 원 + 흰 별)
class StarPinPainter extends CustomPainter {
  const StarPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = math.min(w, h) * 0.42;
    final center = Offset(w / 2, h / 2);

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Colors.black.withAlpha(28),
      4.0,
      false,
    );
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF000000));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final starPath = starPath5(
      center: center,
      outerRadius: radius * 0.55,
      innerRadiusRatio: 0.45,
    );
    canvas.drawPath(starPath, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(StarPinPainter old) => false;
}

/// 별 도형(5각) 경로 — [StarPinPainter]와 [StarOnlyPainter]가 공유.
Path starPath5({
  required Offset center,
  required double outerRadius,
  required double innerRadiusRatio,
  int points = 5,
}) {
  final innerRadius = outerRadius * innerRadiusRatio;
  final path = Path();
  final step = math.pi / points;
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outerRadius : innerRadius;
    final angle = -math.pi / 2 + i * step;
    final point = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  return path;
}

/// 스탬프 셀 전용 — 배지 원은 호출부(Container)가 그리므로 별만 그림.
class StarOnlyPainter extends CustomPainter {
  final Color color;

  const StarOnlyPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2;
    final path = starPath5(
      center: center,
      outerRadius: outerRadius,
      innerRadiusRatio: 0.45,
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(StarOnlyPainter old) => color != old.color;
}
