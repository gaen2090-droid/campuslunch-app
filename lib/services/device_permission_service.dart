import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 위치 정확도 보조 권한(주변 기기·Wi-Fi 스캔)
abstract final class DevicePermissionService {
  /// 위치 권한 직후 호출. 거부해도 위치만 허용됐으면 앱 진행 가능.
  static Future<void> requestAndroidNearbyScanForLocation() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
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
