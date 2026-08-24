import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 설치 단위 고정 ID (재설치 시 바뀜). 다중 계정 어뷰징 감지용.
const _kDeviceInstallId = 'cl_device_install_id';

String _newId() {
  final r = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
  return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
}

Future<String> getOrCreateDeviceInstallId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_kDeviceInstallId);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = _newId();
  await prefs.setString(_kDeviceInstallId, id);
  return id;
}
