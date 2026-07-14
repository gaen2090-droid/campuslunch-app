import 'dart:math' as math;

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
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF111827));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final starPath = _starPath(
      center: center,
      outerRadius: radius * 0.55,
      innerRadiusRatio: 0.45,
      points: 5,
    );
    canvas.drawPath(starPath, Paint()..color = Colors.white);
  }

  static Path _starPath({
    required Offset center,
    required double outerRadius,
    required double innerRadiusRatio,
    required int points,
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

  @override
  bool shouldRepaint(StarPinPainter old) => false;
}

/// 클러스터 개수 배지 — 반투명 원 + 중앙 숫자 (부동산 지도 스타일)
class ClusterBadgePainter extends CustomPainter {
  final int count;

  const ClusterBadgePainter({required this.count});

  /// 자릿수 구간별 반지름 비율(캔버스 대비)과 폰트 크기(px, 캔버스가 [w]x[w]일 때 기준)
  static ({double radiusRatio, double fontRatio}) _tierFor(int count) {
    if (count >= 100) return (radiusRatio: 0.46, fontRatio: 0.30);
    if (count >= 10) return (radiusRatio: 0.42, fontRatio: 0.33);
    return (radiusRatio: 0.36, fontRatio: 0.38);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final tier = _tierFor(count);
    final radius = w * tier.radiusRatio;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF3182F6).withAlpha(191),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withAlpha(217)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    final label = count > 999 ? '999+' : '$count';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: w * tier.fontRatio,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(ClusterBadgePainter old) => count != old.count;
}
