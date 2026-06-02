import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/restaurant.dart';

/// 목록 `영업안함` 뱃지와 동일한 회색(0xFF9CA3AF) 마커
class MapMarkerIcons {
  static BitmapDescriptor? _closed;

  static Future<BitmapDescriptor> closed() async {
    if (_closed != null) return _closed!;
    _closed = await _pinMarker(const Color(0xFF9CA3AF));
    return _closed!;
  }

  static Future<BitmapDescriptor> _pinMarker(Color color) async {
    const w = 48.0;
    const h = 56.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fill = Paint()..color = color;
    final shadow = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    const headCenter = Offset(w / 2, 18);
    const headRadius = 16.0;

    canvas.drawCircle(headCenter.translate(0, 1), headRadius, shadow);
    canvas.drawCircle(headCenter, headRadius, fill);

    final tail = Path()
      ..moveTo(w / 2, h - 2)
      ..lineTo(w / 2 - 11, headCenter.dy + 10)
      ..lineTo(w / 2 + 11, headCenter.dy + 10)
      ..close();
    canvas.drawPath(tail, fill);

    canvas.drawCircle(headCenter, 6, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  static Color listColorForStatus(String status) {
    return Color(statusMetaMap[status]?.color ?? 0xFF9CA3AF);
  }
}
