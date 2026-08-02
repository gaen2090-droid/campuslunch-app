/// 앱 UI 혼잡도(한글) ↔ Supabase `crowd_level` enum (normal | full | closed)
class CrowdLevelMapper {
  static const _toDb = {
    '여유로움': 'normal',
    '약간혼잡': 'full',
    '자리없음': 'full',
    '영업안함': 'closed',
  };

  static const _fromDb = {
    'normal': '여유로움',
    'full': '약간혼잡',
    'closed': '영업안함',
  };

  static String toDb(String uiStatus) => _toDb[uiStatus] ?? 'normal';

  static String fromDb(String dbLevel, {Map<String, dynamic>? metadata}) {
    final fromMeta = metadata?['status'];
    if (fromMeta is String &&
        fromMeta.isNotEmpty &&
        _toDb.containsKey(fromMeta)) {
      return fromMeta;
    }
    return _fromDb[dbLevel] ?? '여유로움';
  }
}
