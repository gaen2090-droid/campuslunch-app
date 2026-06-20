import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/restaurant.dart';
import 'map_pin_painter.dart';

/// 카카오맵 커스텀 마커용 PNG 바이트 생성
///
/// Flutter PNG 인코딩은 iOS Kakao SDK에서 SIGABRT → raw RGBA 후 `image`로 표준 PNG 생성.
class MapMarkerIcons {
  static Uint8List? _closedBytes;
  static Uint8List? _noReportBytes;
  static final Map<int, Uint8List> _colorCache = {};

  static Future<Uint8List> closed() async {
    _closedBytes ??= await _pinMarkerBytes(const Color(0xFF9CA3AF));
    return _closedBytes!;
  }

  static Future<Uint8List> noReport() async {
    _noReportBytes ??= await _pinMarkerBytes(const Color(0xFF111827));
    return _noReportBytes!;
  }

  static Future<Uint8List> forStatus(String status) async {
    final color = Color(statusMetaMap[status]?.color ?? 0xFF9CA3AF);
    final key = color.toARGB32();
    if (_colorCache.containsKey(key)) return _colorCache[key]!;
    final bytes = await _pinMarkerBytes(color);
    _colorCache[key] = bytes;
    return bytes;
  }

  /// Google Maps 스타일 통짜 핀 (MapPinPainter와 동일)
  static Future<Uint8List> _pinMarkerBytes(Color color) async {
    const w = 40;
    const h = 54;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    MapPinPainter(fillColor: color).paint(
      canvas,
      Size(w.toDouble(), h.toDouble()),
    );

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(w, h);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();

    if (byteData == null) {
      throw StateError('Failed to render map pin bytes');
    }

    final image = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: byteData.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodePng(image));
  }

  static String styleIdForStatus(String status) {
    switch (status) {
      case '여유로움':
        return 'pin_relaxed';
      case '약간혼잡':
        return 'pin_moderate';
      case '자리없음':
        return 'pin_full';
      case '영업안함':
        return 'pin_closed';
      default:
        return 'pin_unknown';
    }
  }

  static Future<List<MarkerStyleBundle>> buildStatusStyles() async {
    final styles = <MarkerStyleBundle>[];
    for (final entry in statusMetaMap.entries) {
      styles.add(MarkerStyleBundle(
        styleId: styleIdForStatus(entry.key),
        bytes: await forStatus(entry.key),
      ));
    }
    styles.add(MarkerStyleBundle(
      styleId: 'pin_no_report',
      bytes: await noReport(),
    ));
    styles.add(MarkerStyleBundle(
      styleId: 'pin_my_location',
      bytes: await _pinMarkerBytes(const Color(0xFF2563EB)),
    ));
    styles.add(MarkerStyleBundle(
      styleId: 'pin_destination',
      bytes: await _pinMarkerBytes(const Color(0xFFEF4444)),
    ));
    return styles;
  }
}

class MarkerStyleBundle {
  final String styleId;
  final Uint8List bytes;

  const MarkerStyleBundle({required this.styleId, required this.bytes});
}

int markerColorForStatus(String status) {
  final meta = statusMetaMap[status];
  return meta?.color ?? 0xFF9CA3AF;
}
