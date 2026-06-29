import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/restaurant.dart';
import 'map_pin_painter.dart';

/// 지도(마커·범례)에서만 statusMetaMap과 다른 색을 쓰는 경우의 오버라이드.
/// 약간혼잡: 지도 위에서는 더 밝은 노랑으로 — 카드 뱃지 색(statusMetaMap)은 그대로 유지.
const Map<String, int> mapStatusColorOverrides = {
  '약간혼잡': 0xFFFBBF24,
};

int mapStatusColor(String status) =>
    mapStatusColorOverrides[status] ?? statusMetaMap[status]?.color ?? 0xFF9CA3AF;

/// 카카오맵 커스텀 마커용 PNG 바이트 생성
///
/// Flutter PNG 인코딩은 iOS Kakao SDK에서 SIGABRT → raw RGBA 후 `image`로 표준 PNG 생성.
class MapMarkerIcons {
  static Uint8List? _closedBytes;
  static Uint8List? _noReportBytes;
  static final Map<int, Uint8List> _colorCache = {};

  /// 핀 디자인 변경 시 캐시 무효화 (hot reload 대응)
  static void clearCache() {
    _closedBytes = null;
    _noReportBytes = null;
    _colorCache.clear();
  }

  static Future<Uint8List> closed() async {
    _closedBytes ??= await _pinMarkerBytes(const Color(0xFF9CA3AF));
    return _closedBytes!;
  }

  static Future<Uint8List> noReport() async {
    _noReportBytes ??= await _pinMarkerBytes(const Color(0xFF111827));
    return _noReportBytes!;
  }

  static Future<Uint8List> forStatus(String status) async {
    final color = Color(mapStatusColor(status));
    final key = color.toARGB32();
    if (_colorCache.containsKey(key)) return _colorCache[key]!;
    final bytes = await _pinMarkerBytes(color);
    _colorCache[key] = bytes;
    return bytes;
  }

  /// 카카오맵 POI 핀 — 2x 크기 + 2x 슈퍼샘플링
  static Future<Uint8List> _pinMarkerBytes(Color color) async {
    const w = 72;
    const h = 88;
    const pixelRatio = 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio.toDouble());
    MapPinPainter(fillColor: color).paint(
      canvas,
      Size(w.toDouble(), h.toDouble()),
    );

    final picture = recorder.endRecording();
    final rw = w * pixelRatio;
    final rh = h * pixelRatio;
    final uiImage = await picture.toImage(rw, rh);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();

    if (byteData == null) {
      throw StateError('Failed to render map pin bytes');
    }

    final hiRes = img.Image.fromBytes(
      width: rw,
      height: rh,
      bytes: byteData.buffer,
      bytesOffset: byteData.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final image = img.copyResize(
      hiRes,
      width: w,
      height: h,
      interpolation: img.Interpolation.linear,
    );
    final png = Uint8List.fromList(img.encodePng(image));
    if (!_isValidPng(png)) {
      throw StateError('Generated PNG failed signature check');
    }
    if (img.decodeImage(png) == null) {
      throw StateError('Generated PNG failed round-trip decode');
    }
    return png;
  }

  static bool _isValidPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  static String styleIdForStatus(String status) {
    switch (status) {
      case '여유로움':
        return 'pin_relaxed';
      case '약간혼잡':
        return 'pin_moderate';
      case '자리없음':
        return 'pin_full';
      case '웨이팅많음':
        return 'pin_hot_waiting';
      case '영업안함':
        return 'pin_closed';
      default:
        return 'pin_unknown';
    }
  }

  static Future<List<MarkerStyleBundle>> buildStatusStyles() async {
    clearCache();
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
      bytes: await _pinMarkerBytes(const Color(0xFF3182F6)),
    ));
    styles.add(MarkerStyleBundle(
      styleId: 'pin_destination',
      bytes: await _pinMarkerBytes(const Color(0xFFF04452)),
    ));
    return styles;
  }
}

class MarkerStyleBundle {
  final String styleId;
  final Uint8List bytes;

  const MarkerStyleBundle({required this.styleId, required this.bytes});
}

int markerColorForStatus(String status) => mapStatusColor(status);
