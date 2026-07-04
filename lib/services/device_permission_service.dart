import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 위치 정확도 보조 권한(주변 기기·Wi-Fi 스캔)
abstract final class DevicePermissionService {
  /// Android 전용. 확인 버튼 → 위치 허용 직후에만 호출.
  /// iOS는 no-op (로컬 네트워크 팝업은 Flutter 디버그 연결이 앱 시작 시 띄움).
  static Future<void> requestAndroidNearbyScanForLocation() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('[Permissions] nearby scan skipped (not Android)');
      return;
    }

    try {
      debugPrint('[Permissions] requesting Android nearby scan permissions');
      final scan = await Permission.bluetoothScan.request();
      debugPrint('[Permissions] bluetoothScan=$scan');
      final connect = await Permission.bluetoothConnect.request();
      debugPrint('[Permissions] bluetoothConnect=$connect');
      final wifi = await Permission.nearbyWifiDevices.request();
      debugPrint('[Permissions] nearbyWifiDevices=$wifi');
    } catch (e, st) {
      debugPrint('[Permissions] nearby scan request failed: $e\n$st');
    }
  }
}
