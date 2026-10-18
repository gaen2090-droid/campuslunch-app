import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image/image.dart' as img;

import '../models/restaurant.dart';
import 'map_pin_painter.dart';

/// 지도(마커·범례)에서만 statusMetaMap과 다른 색을 쓰는 경우의 오버라이드.
/// 카드 뱃지 색(statusMetaMap)과는 별개로 지도 마커 전용 브랜드 컬러를 사용.
const Map<String, int> mapStatusColorOverrides = {
  '여유로움': 0xFF26BC7D,
  '약간혼잡': 0xFFFFBF00,
  '자리없음': 0xFFEF4444,
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
  static List<MarkerStyleBundle>? _cachedBundles;
  static Future<List<MarkerStyleBundle>>? _bundlesInFlight;
  static bool _uiReady = false;

  /// 핀 디자인 변경 시 캐시 무효화 (hot reload 대응)
  static void clearCache() {
    _closedBytes = null;
    _noReportBytes = null;
    _colorCache.clear();
    _predictedCache.clear();
    _cachedBundles = null;
    _bundlesInFlight = null;
    _uiReady = false;
  }

  /// release APK에서 main() 직후 toImage()가 실패하는 경우 방지
  static Future<void> _awaitFlutterUiReady() async {
    if (_uiReady) return;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle) {
      await Future<void>.delayed(Duration.zero);
    } else {
      await binding.endOfFrame;
    }
    _uiReady = true;
  }

  static Future<Uint8List> closed() async {
    _closedBytes ??= await _pinMarkerBytes(const Color(0xFF9CA3AF));
    return _closedBytes!;
  }

  static Future<Uint8List> noReport() async {
    _noReportBytes ??= await _starMarkerBytes();
    return _noReportBytes!;
  }

  /// '제보필요' 전용 마커 — 검정 원 + 흰색 별 (스탬프 아이콘 스타일)
  static Future<Uint8List> _starMarkerBytes() async {
    await _awaitFlutterUiReady();
    try {
      return await _starMarkerBytesFromCanvas();
    } catch (e, st) {
      debugPrint('[MapMarkerIcons] canvas star failed, using fallback: $e\n$st');
      return _fallbackPinPng(const Color(0xFF000000));
    }
  }

  static Future<Uint8List> _starMarkerBytesFromCanvas() async {
    const w = 48;
    const h = 48;
    const pixelRatio = 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio.toDouble());
    const StarPinPainter().paint(canvas, Size(w.toDouble(), h.toDouble()));

    final picture = recorder.endRecording();
    final rw = w * pixelRatio;
    final rh = h * pixelRatio;
    final uiImage = await picture.toImage(rw, rh);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();

    if (byteData == null) {
      throw StateError('Failed to render star marker bytes');
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

  /// 예측 마커 — 같은 색 핀 바로 위 가운데에 작은 `예측` 태그를 붙인다.
  /// 핀 머리가 가려지지 않도록 캔버스를 위로 늘리고 핀은 아래에 둔다
  /// (이미지 아래 가운데가 가게 위치라서 핀 끝 위치는 일반 핀과 같다).
  static final Map<int, Uint8List> _predictedCache = {};

  static Future<Uint8List> predicted(String status) async {
    final color = Color(mapStatusColor(status));
    final key = color.toARGB32();
    final cached = _predictedCache[key];
    if (cached != null) return cached;
    await _awaitFlutterUiReady();
    Uint8List bytes;
    try {
      bytes = await _predictedPinBytesFromCanvas(color);
    } catch (e, st) {
      debugPrint('[MapMarkerIcons] canvas predicted pin failed, using plain pin: $e\n$st');
      bytes = await forStatus(status);
    }
    _predictedCache[key] = bytes;
    return bytes;
  }

  static Future<Uint8List> _predictedPinBytesFromCanvas(Color color) async {
    const pinW = 72;
    const pinH = 66;
    // 태그가 들어갈 위쪽 여백. 태그(글자 20 + 위아래 3)는 핀 머리 위에 살짝 걸쳐도 되는 높이.
    const tagArea = 24;
    const w = pinW;
    const h = pinH + tagArea;
    const pixelRatio = 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio.toDouble());

    canvas.save();
    canvas.translate(0, tagArea.toDouble());
    MapPinPainter(fillColor: color).paint(canvas, Size(pinW.toDouble(), pinH.toDouble()));
    canvas.restore();

    paintPredictionTag(canvas, centerX: w / 2, top: 1, color: color);

    final picture = recorder.endRecording();
    final rw = w * pixelRatio;
    final rh = h * pixelRatio;
    final uiImage = await picture.toImage(rw, rh);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();

    if (byteData == null) {
      throw StateError('Failed to render predicted pin bytes');
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
    await _awaitFlutterUiReady();
    try {
      return await _pinMarkerBytesFromCanvas(color);
    } catch (e, st) {
      debugPrint('[MapMarkerIcons] canvas pin failed, using fallback: $e\n$st');
      return _fallbackPinPng(color);
    }
  }

  static Future<Uint8List> _pinMarkerBytesFromCanvas(Color color) async {
    const w = 72;
    const h = 66;
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

  /// 내 위치 마커 — 다른 매장 핀과 겹치지 않도록 원형 도트로 차별화
  /// (파란 원 + 흰 테두리 + 은은한 외곽 헤일로). 카카오맵 SDK의 MarkerOption에는
  /// 회전 속성이 없어 기기 방향을 따라 도는 나침반 삼각형은 구현할 수 없음.
  static Future<Uint8List> _myLocationMarkerBytes() async {
    await _awaitFlutterUiReady();
    try {
      return await _myLocationMarkerBytesFromCanvas();
    } catch (e, st) {
      debugPrint('[MapMarkerIcons] canvas my-location failed, using fallback: $e\n$st');
      return _fallbackDotPng(const Color(0xFF3182F6));
    }
  }

  static Future<Uint8List> _myLocationMarkerBytesFromCanvas() async {
    const w = 48;
    const h = 48;
    const pixelRatio = 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio.toDouble());

    final center = Offset(w / 2, h / 2);
    const color = Color(0xFF3182F6);

    // 은은한 외곽 헤일로 (움직임 감지되는 위치임을 표현)
    canvas.drawCircle(
      center,
      18,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    // 흰 테두리
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    // 파란 코어
    canvas.drawCircle(center, 9, Paint()..color = color);

    final picture = recorder.endRecording();
    final rw = w * pixelRatio;
    final rh = h * pixelRatio;
    final uiImage = await picture.toImage(rw, rh);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();

    if (byteData == null) {
      throw StateError('Failed to render my-location marker bytes');
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

  /// Canvas 렌더 실패 시 도트 마커 fallback
  static Uint8List _fallbackDotPng(Color color) {
    const w = 48;
    const h = 48;
    final image = img.Image(width: w, height: h, numChannels: 4);
    final c = img.ColorRgba8(
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
      255,
    );
    final cx = w ~/ 2;
    final cy = h ~/ 2;
    img.fillCircle(image, x: cx, y: cy, radius: 18, color: img.ColorRgba8(c.r.toInt(), c.g.toInt(), c.b.toInt(), 46));
    img.fillCircle(image, x: cx, y: cy, radius: 11, color: img.ColorRgba8(255, 255, 255, 255));
    img.fillCircle(image, x: cx, y: cy, radius: 9, color: c);
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Canvas 렌더 실패 시 image 패키지로 단순 핀 생성 (네이티브 등록용)
  static Uint8List _fallbackPinPng(Color color) {
    const w = 72;
    const h = 66;
    final image = img.Image(width: w, height: h, numChannels: 4);
    final c = img.ColorRgba8(
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
      255,
    );
    final cx = w ~/ 2;
    final headR = 20;
    final headCy = 25;
    img.fillCircle(image, x: cx, y: headCy, radius: headR + 2, color: img.ColorRgba8(255, 255, 255, 255));
    img.fillCircle(image, x: cx, y: headCy, radius: headR, color: c);
    img.fillCircle(image, x: cx, y: headCy, radius: 8, color: img.ColorRgba8(255, 255, 255, 230));
    for (var y = headCy + headR - 2; y < h - 4; y++) {
      final t = (y - (headCy + headR - 2)) / (h - 4 - (headCy + headR - 2));
      final half = (12 * (1 - t)).round().clamp(1, 12);
      for (var x = cx - half; x <= cx + half; x++) {
        image.setPixel(x, y, c);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  static bool _isValidPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  /// 예측 마커 스타일 id (일반 핀과 별개로 등록한다).
  static String styleIdForPrediction(String status) {
    switch (status) {
      case '여유로움':
        return 'pin_pred_relaxed';
      case '약간혼잡':
        return 'pin_pred_moderate';
      default:
        return 'pin_pred_full';
    }
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
    final cached = _cachedBundles;
    if (cached != null) return cached;

    final inFlight = _bundlesInFlight;
    if (inFlight != null) return inFlight;

    final task = _buildStatusStylesImpl();
    _bundlesInFlight = task;
    try {
      final bundles = await task;
      _cachedBundles = bundles;
      return bundles;
    } finally {
      if (identical(_bundlesInFlight, task)) {
        _bundlesInFlight = null;
      }
    }
  }

  static Future<List<MarkerStyleBundle>> _buildStatusStylesImpl() async {
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
    for (final status in const ['여유로움', '약간혼잡', '자리없음']) {
      styles.add(MarkerStyleBundle(
        styleId: styleIdForPrediction(status),
        bytes: await predicted(status),
      ));
    }
    styles.add(MarkerStyleBundle(
      styleId: 'pin_my_location',
      bytes: await _myLocationMarkerBytes(),
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
