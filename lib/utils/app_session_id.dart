import 'dart:math';

/// 앱 프로세스(콜드 스타트)당 1회 생성되는 세션 ID.
String? _cachedAppSessionId;

String _newId() {
  final r = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
  return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
}

String getAppSessionId() {
  return _cachedAppSessionId ??= _newId();
}
