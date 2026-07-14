import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum RecentHistoryType { search, restaurant }

/// 검색 화면의 "최근 목록" 항목 — 검색어 제출 또는 매장 열람 시 기록됨.
class RecentHistoryEntry {
  final RecentHistoryType type;
  final String label; // 검색어 텍스트 또는 매장명
  final String? restaurantId; // type == restaurant일 때만
  final DateTime timestamp;

  const RecentHistoryEntry({
    required this.type,
    required this.label,
    this.restaurantId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'label': label,
        'restaurantId': restaurantId,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is RecentHistoryEntry &&
      other.type == type &&
      other.label == label &&
      other.restaurantId == restaurantId &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(type, label, restaurantId, timestamp);

  factory RecentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RecentHistoryEntry(
      type: RecentHistoryType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => RecentHistoryType.search,
      ),
      label: json['label'] as String,
      restaurantId: json['restaurantId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// 화면별 최근 목록 저장소(검색어 제출 + 매장 열람을 하나의 시간순 리스트로 저장,
/// 카카오맵 "최근" 탭과 동일한 개념). 화면마다 [key]로 저장소를 구분한다.
class RecentHistoryStore {
  static const _maxEntries = 20;

  final String _prefsKey;

  const RecentHistoryStore(String key) : _prefsKey = 'cl_recent_history_$key';

  Future<List<RecentHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecentHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<RecentHistoryEntry>> _persist(
    List<RecentHistoryEntry> entries,
  ) async {
    final capped = entries.take(_maxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );
    return capped;
  }

  Future<List<RecentHistoryEntry>> addSearch(
    String query,
    List<RecentHistoryEntry> current,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return current;
    final filtered = current
        .where((e) => !(e.type == RecentHistoryType.search && e.label == trimmed))
        .toList();
    final updated = [
      RecentHistoryEntry(
        type: RecentHistoryType.search,
        label: trimmed,
        timestamp: DateTime.now(),
      ),
      ...filtered,
    ];
    return _persist(updated);
  }

  Future<List<RecentHistoryEntry>> addRestaurant(
    String restaurantId,
    String name,
    List<RecentHistoryEntry> current,
  ) async {
    final filtered = current
        .where((e) =>
            !(e.type == RecentHistoryType.restaurant && e.restaurantId == restaurantId))
        .toList();
    final updated = [
      RecentHistoryEntry(
        type: RecentHistoryType.restaurant,
        label: name,
        restaurantId: restaurantId,
        timestamp: DateTime.now(),
      ),
      ...filtered,
    ];
    return _persist(updated);
  }

  Future<List<RecentHistoryEntry>> remove(
    RecentHistoryEntry entry,
    List<RecentHistoryEntry> current,
  ) async {
    final updated = current.where((e) => e != entry).toList();
    return _persist(updated);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
