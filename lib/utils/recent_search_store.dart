import 'package:shared_preferences/shared_preferences.dart';

/// 화면별 최근 검색어 저장/조회 (SharedPreferences 기반, 화면마다 key로 구분).
class RecentSearchStore {
  static const _maxEntries = 10;

  final String _prefsKey;

  const RecentSearchStore(String key) : _prefsKey = 'cl_recent_search_$key';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
  }

  Future<List<String>> save(String query, List<String> current) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return current;
    final prefs = await SharedPreferences.getInstance();
    final updated = [trimmed, ...current.where((q) => q != trimmed)];
    final capped = updated.take(_maxEntries).toList();
    await prefs.setStringList(_prefsKey, capped);
    return capped;
  }

  Future<List<String>> remove(String query, List<String> current) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = current.where((q) => q != query).toList();
    await prefs.setStringList(_prefsKey, updated);
    return updated;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
