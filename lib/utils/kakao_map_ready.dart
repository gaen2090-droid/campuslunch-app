import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import 'map_marker_icons.dart';

/// kakao_maps_flutter는 onMapCreated 직후엔 네이티브 MapView가 아직 준비되지 않음.
Future<void> runWhenKakaoMapReady(
  KakaoMapController controller,
  Future<void> Function() action, {
  Duration maxWait = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(maxWait);
  Object? lastError;

  while (DateTime.now().isBefore(deadline)) {
    try {
      await action();
      return;
    } on AssertionError catch (e) {
      lastError = e;
      await Future.delayed(const Duration(milliseconds: 100));
    } on PlatformException catch (e) {
      lastError = e;
      final msg = e.message ?? '';
      if (e.code == 'E000' || msg.contains('MapView not found')) {
        await Future.delayed(const Duration(milliseconds: 100));
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

/// 마커 레이어 + 커스텀 핀 스타일 (viewId별 상태)
class KakaoMarkerLayer {
  static final Map<int, bool> _stylesReadyByViewId = {};
  static final Set<int> _layerReadyViewIds = {};

  static bool isReady(KakaoMapController controller) =>
      _stylesReadyByViewId[controller.viewId] == true;

  static Future<void> ensure(KakaoMapController controller) async {
    final viewId = controller.viewId;

    if (_stylesReadyByViewId[viewId] != true) {
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
      _stylesReadyByViewId[viewId] = true;
      debugPrint(
        '[KakaoMarkerLayer] styles registered viewId=$viewId (${bundles.length})',
      );
    }

    if (_layerReadyViewIds.contains(viewId)) return;

    await controller.addMarkerLayer(
      layerId: KakaoMapController.defaultLabelLayerId,
      zOrder: 1000,
      clickable: true,
    );
    _layerReadyViewIds.add(viewId);
  }

  static String? styleIdOrNull(KakaoMapController controller, String styleId) =>
      isReady(controller) ? styleId : null;
}

Future<void> ensureKakaoMarkerLayer(KakaoMapController controller) =>
    KakaoMarkerLayer.ensure(controller);

Future<void> removeMarkerQuietly(
  KakaoMapController controller, {
  required String id,
}) async {
  try {
    await controller.removeMarker(id: id);
  } catch (_) {}
}
