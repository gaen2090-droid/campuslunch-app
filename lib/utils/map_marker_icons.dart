import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/restaurant.dart';

/// 카카오맵 커스텀 마커용 PNG 바이트 생성
///
/// Flutter `toImage` PNG는 iOS Kakao SDK에서 SIGABRT → `image` 패키지로 표준 PNG 생성.
class MapMarkerIcons {
  static Uint8List? _closedBytes;
  static Uint8List? _noReportBytes;
  static final Map<int, Uint8List> _colorCache = {};

  static Uint8List closed() {
    _closedBytes ??= _pinMarkerBytes(const Color(0xFF9CA3AF));
    return _closedBytes!;
  }

  static Uint8List noReport() {
    _noReportBytes ??= _pinMarkerBytes(const Color(0xFF111827));
    return _noReportBytes!;
  }

  static Uint8List forStatus(String status) {
    final color = Color(statusMetaMap[status]?.color ?? 0xFF9CA3AF);
    final key = color.toARGB32();
    if (_colorCache.containsKey(key)) return _colorCache[key]!;
    final bytes = _pinMarkerBytes(color);
    _colorCache[key] = bytes;
    return bytes;
  }

  /// 48×56 물방울 핀 (기존 CustomPaint 디자인과 동일)
  static Uint8List _pinMarkerBytes(Color color) {
    const w = 48;
    const h = 56;
    const headCx = 24;
    const headCy = 18;
    const headRadius = 16;

    final image = img.Image(width: w, height: h, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

    final fill = _toRgba(color);
    final shadow = img.ColorRgba8(0, 0, 0, 66);

    img.fillCircle(
      image,
      x: headCx,
      y: headCy + 1,
      radius: headRadius,
      color: shadow,
    );
    img.fillCircle(
      image,
      x: headCx,
      y: headCy,
      radius: headRadius,
      color: fill,
    );
    img.fillPolygon(
      image,
      vertices: [
        img.Point(headCx, h - 2),
        img.Point(headCx - 11, headCy + 10),
        img.Point(headCx + 11, headCy + 10),
      ],
      color: fill,
    );
    img.fillCircle(
      image,
      x: headCx,
      y: headCy,
      radius: 6,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    return Uint8List.fromList(img.encodePng(image));
  }

  static img.ColorRgba8 _toRgba(Color color) {
    final c = color.toARGB32();
    return img.ColorRgba8(
      (c >> 16) & 0xFF,
      (c >> 8) & 0xFF,
      c & 0xFF,
      (c >> 24) & 0xFF,
    );
  }

  static String styleIdForStatus(String status) => 'pin_$status';

  static List<MarkerStyleBundle> buildStatusStyles() {
    final styles = <MarkerStyleBundle>[];
    for (final entry in statusMetaMap.entries) {
      styles.add(MarkerStyleBundle(
        styleId: styleIdForStatus(entry.key),
        bytes: forStatus(entry.key),
      ));
    }
    styles.add(MarkerStyleBundle(
      styleId: styleIdForStatus('영업안함'),
      bytes: closed(),
    ));
    styles.add(MarkerStyleBundle(
      styleId: 'pin_no_report',
      bytes: noReport(),
    ));
    styles.add(MarkerStyleBundle(
      styleId: 'pin_my_location',
      bytes: _pinMarkerBytes(const Color(0xFF2563EB)),
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
