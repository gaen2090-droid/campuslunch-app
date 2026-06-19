import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import 'map_marker_icons.dart';

/// kakao_maps_flutter는 onMapCreated 직후엔 네이티브 MapView가 아직 준비되지 않음.
Future<void> runWhenKakaoMapReady(
  KakaoMapController controller,
  Future<void> Function() action, {
  Duration maxWait = const Duration(seconds: 12),
}) async {
  final deadline = DateTime.now().add(maxWait);
  Object? lastError;

  while (DateTime.now().isBefore(deadline)) {
    try {
      await action();
      return;
    } on AssertionError catch (e) {
      lastError = e;
      await Future.delayed(const Duration(milliseconds: 80));
    } on PlatformException catch (e) {
      lastError = e;
      final msg = e.message ?? '';
      if (e.code == 'E000' || msg.contains('MapView not found')) {
        await Future.delayed(const Duration(milliseconds: 80));
        continue;
      }
      rethrow;
    }
  }

  debugPrint('[KakaoMap] map ready timeout after ${maxWait.inSeconds}s: $lastError');
}

const _markerTextStyle = MarkerTextStyle(
  fontSize: 14,
  fontColorArgb: 0xFF111827,
  strokeThickness: 3,
  strokeColorArgb: 0xFFFFFFFF,
);

/// 마커 레이어 + 커스텀 핀 스타일
class KakaoMarkerLayer {
  static bool customStylesAvailable = false;
  static final Set<int> _layerReadyViewIds = {};

  static Future<void> ensure(KakaoMapController controller) async {
    customStylesAvailable = false;

    await _registerStyles(controller);

    final viewId = controller.viewId;
    if (_layerReadyViewIds.contains(viewId)) return;

    await controller.addMarkerLayer(
      layerId: KakaoMapController.defaultLabelLayerId,
      zOrder: 1000,
      clickable: true,
    );
    _layerReadyViewIds.add(viewId);
  }

  static Future<void> _registerStyles(KakaoMapController controller) async {
    try {
      final bundles = MapMarkerIcons.buildStatusStyles();

      await controller.registerMarkerStyles(
        styles: bundles
            .map(
              (s) => MarkerStyle(
                styleId: s.styleId,
                perLevels: [
                  MarkerPerLevelStyle.fromBytes(
                    bytes: s.bytes,
                    level: 15,
                    textStyle: _markerTextStyle,
                  ),
                ],
              ),
            )
            .toList(),
      );
      customStylesAvailable = true;
      debugPrint(
        '[KakaoMarkerLayer] custom pin styles registered (${bundles.length})',
      );
    } catch (e, st) {
      debugPrint('[KakaoMarkerLayer] style registration failed: $e\n$st');
    }
  }

  static String? styleIdOrNull(String styleId) =>
      customStylesAvailable ? styleId : null;
}

Future<void> ensureKakaoMarkerLayer(KakaoMapController controller) =>
    KakaoMarkerLayer.ensure(controller);
