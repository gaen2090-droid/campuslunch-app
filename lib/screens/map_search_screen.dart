import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/recent_history_store.dart';
import '../widgets/recent_history_row.dart';
import '../widgets/restaurant_card.dart';

/// 지도 화면 검색 — 지도 위 오버레이로 표시된다(별도 라우트 push 금지).
/// 검색 화면 진입/이탈 시 라우트 전환(didPopNext)이 발생하면 네이티브 카카오맵
/// virtual display가 파괴·재생성되며 검은 화면/리사이즈/버벅임이 생기므로, 지도
/// 화면을 마운트한 채로 그 위에 이 위젯을 겹쳐 보여주는 방식으로 바꿨다.
/// 타이핑만으로도 결과가 즉시 뜨지만, 최근 목록에는
/// "검색 제출(아이콘/엔터)"과 "매장 열람"만 시간순으로 함께 기록된다.
class MapSearchScreen extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<Restaurant> onSelectRestaurant;

  const MapSearchScreen({
    super.key,
    required this.onClose,
    required this.onSelectRestaurant,
  });

  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  static const _historyStore = RecentHistoryStore('map');

  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<RecentHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await _historyStore.load();
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _submitSearch(String query) async {
    if (query.trim().isEmpty) return;
    final updated = await _historyStore.addSearch(query, _history);
    if (!mounted) return;
    setState(() => _history = updated);
  }

  Future<void> _selectRestaurant(Restaurant r) async {
    final updated = await _historyStore.addRestaurant(r.id, r.name, _history);
    if (!mounted) return;
    setState(() => _history = updated);
    widget.onSelectRestaurant(r);
  }

  Future<void> _removeHistoryEntry(RecentHistoryEntry entry) async {
    final updated = await _historyStore.remove(entry, _history);
    if (!mounted) return;
    setState(() => _history = updated);
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear();
    if (!mounted) return;
    setState(() => _history = []);
  }

  List<Restaurant> _search(List<Restaurant> all, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return all
        .where((r) => '${r.name} ${r.area} ${r.category}'.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppProvider>().restaurants;
    final results = _search(all, _searchCtrl.text);
    final byId = {for (final r in all) r.id: r};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: Container(
        color: Colors.white,
        child: SafeArea(
          // 지도 탭 Scaffold가 resizeToAvoidBottomInset: false라 body 크기가
          // 키보드와 무관하게 고정된다(지도 PlatformView 리사이즈 방지 목적)
          // — 이 오버레이는 그 안에 얹히므로 키보드에 가려지는 만큼을 직접
          // 패딩으로 보정해야 한다.
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                _searchBar(),
                Expanded(child: _body(results, byId)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _submitSearch(_searchCtrl.text),
                    child: const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submitSearch,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(
                        hintText: '매장명, 위치, 음식종류 검색',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _searchCtrl.clear()),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onClose,
            child: const Text('취소',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  Widget _body(List<Restaurant> results, Map<String, Restaurant> byId) {
    if (_searchCtrl.text.trim().isEmpty) {
      return _buildHistory(byId);
    }
    if (results.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없어요.',
          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => RestaurantCard(
        restaurant: results[i],
        onTap: () => _selectRestaurant(results[i]),
      ),
    );
  }

  Widget _buildHistory(Map<String, Restaurant> byId) {
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          '최근 검색 내역이 없어요.',
          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('최근',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
              GestureDetector(
                onTap: _clearHistory,
                child: const Text('전체삭제',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
            itemBuilder: (_, i) {
              final entry = _history[i];
              return RecentHistoryRow(
                entry: entry,
                onTap: () {
                  if (entry.type == RecentHistoryType.search) {
                    _searchCtrl.value = TextEditingValue(
                      text: entry.label,
                      selection: TextSelection.collapsed(offset: entry.label.length),
                    );
                    setState(() {});
                  } else {
                    final restaurant = byId[entry.restaurantId];
                    if (restaurant != null) {
                      _selectRestaurant(restaurant);
                    }
                  }
                },
                onRemove: () => _removeHistoryEntry(entry),
              );
            },
          ),
        ),
      ],
    );
  }
}
