import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../models/map_lat_lng.dart';

/// 카카오맵 위에 도보 경로 polyline을 그리는 오버레이.
class RoutePolylineOverlay extends StatefulWidget {
  final KakaoMapController? controller;
  final List<MapLatLng> points;
  final Color color;
  final Color borderColor;
  final double strokeWidth;

  const RoutePolylineOverlay({
    super.key,
    required this.controller,
    required this.points,
    this.color = const Color(0xFF26BC7D),
    this.borderColor = const Color(0xFF1B8F5D),
    this.strokeWidth = 5,
  });

  @override
  State<RoutePolylineOverlay> createState() => _RoutePolylineOverlayState();
}

class _RoutePolylineOverlayState extends State<RoutePolylineOverlay> {
  StreamSubscription? _cameraSub;
  List<Offset>? _screenPoints;
  int _generation = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller, widget.points);
  }

  @override
  void didUpdateWidget(RoutePolylineOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.points != widget.points) {
      _attach(widget.controller, widget.points);
    }
  }

  @override
  void dispose() {
    _cameraSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _attach(KakaoMapController? controller, List<MapLatLng> points) {
    _cameraSub?.cancel();
    _retryTimer?.cancel();
    _cameraSub = controller?.onCameraMoveEndStream.listen((_) {
      _refreshPoints();
    });
    _refreshPoints();
    _retryTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_screenPoints == null || (_screenPoints?.length ?? 0) < 2) {
        _refreshPoints();
      }
    });
  }

  List<MapLatLng> _samplePoints(List<MapLatLng> points) {
    const maxPoints = 150;
    if (points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil().clamp(1, points.length);
    final sampled = <MapLatLng>[];
    for (var i = 0; i < points.length; i += step) {
      sampled.add(points[i]);
    }
    if (sampled.last != points.last) sampled.add(points.last);
    return sampled;
  }

  Future<void> _refreshPoints() async {
    final controller = widget.controller;
    final points = widget.points;
    if (controller == null || points.length < 2) {
      if (mounted) setState(() => _screenPoints = null);
      return;
    }

    final gen = ++_generation;
    final sampled = _samplePoints(points);
    final offsets = <Offset>[];

    for (final point in sampled) {
      final screen = await controller.toScreenPoint(
        position: LatLng(
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      );
      if (screen == null) {
        if (mounted && gen == _generation) {
          setState(() => _screenPoints = null);
        }
        return;
      }
      offsets.add(screen);
    }

    if (!mounted || gen != _generation) return;
    setState(() => _screenPoints = offsets);
    if (offsets.length >= 2) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _screenPoints;
    if (points == null || points.length < 2) {
      return const SizedBox.expand();
    }

    return CustomPaint(
      painter: _RoutePolylinePainter(
        points: points,
        color: widget.color,
        borderColor: widget.borderColor,
        strokeWidth: widget.strokeWidth,
      ),
      size: Size.infinite,
    );
  }
}

class _RoutePolylinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final Color borderColor;
  final double strokeWidth;

  _RoutePolylinePainter({
    required this.points,
    required this.color,
    required this.borderColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth + 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePolylinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
