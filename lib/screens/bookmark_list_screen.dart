import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/load_error_view.dart';
import '../widgets/restaurant_card.dart';
import 'detail_screen.dart';

class BookmarkListScreen extends StatefulWidget {
  const BookmarkListScreen({super.key});

  @override
  State<BookmarkListScreen> createState() => _BookmarkListScreenState();
}

class _BookmarkListScreenState extends State<BookmarkListScreen> {
  static const _allLabel = '전체';
  String _sortBy = '최신순';
  Set<String> _regions = {_allLabel};
  Set<String> _cuisines = {_allLabel};
  String? _openDropdown;
  bool _editMode = false;
  Set<String> _selectedIds = {};

  static const _sortOpts = ['최신순', '인기순', '가까운순', '여유로운순'];
  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [_allLabel, '한식', '중식', '일식', '양식', '아시아', '분식', '카페'];

  bool _isAll(Set<String> values) =>
      values.contains(_allLabel) && values.length == 1;

  void _toggleFilter(Set<String> target, String value) {
    if (value == _allLabel) {
      target..clear()..add(_allLabel);
      return;
    }
    target.remove(_allLabel);
    target.contains(value) ? target.remove(value) : target.add(value);
    if (target.isEmpty) target.add(_allLabel);
  }

  List<Restaurant> _filter(List<Restaurant> all, Set<String> bookmarks) {
    final useAlgo = context.read<AppProvider>().useAlgorithmRanking;
    int popScore(Restaurant r) => useAlgo
        ? (r.popularityScore > 0 ? r.popularityScore : r.totalReports)
        : (r.manualRank > 0 ? -r.manualRank : -9999);

    var list = all.where((r) {
      final regionOk = _regions.contains(_allLabel) || _regions.contains(r.area);
      final cuisineOk = _cuisines.contains(_allLabel) || _cuisines.contains(r.category);
      return bookmarks.contains(r.id) && regionOk && cuisineOk;
    }).toList();
    list.sort((a, b) {
      if (_sortBy == '인기순') return popScore(b).compareTo(popScore(a));
      if (_sortBy == '가까운순') return a.distance.compareTo(b.distance);
      if (_sortBy == '여유로운순') {
        const pri = {'여유로움': 0, '약간혼잡': 1, '자리없음': 2, '웨이팅많음': 2, '영업안함': 3};
        final d = (pri[a.status] ?? 9) - (pri[b.status] ?? 9);
        return d != 0 ? d : popScore(b).compareTo(popScore(a));
      }
      return b.id.compareTo(a.id);
    });
    return list;
  }

  void _enterEdit() => setState(() {
        _editMode = true;
        _selectedIds = {};
        _openDropdown = null;
      });

  void _exitEdit() => setState(() {
        _editMode = false;
        _selectedIds = {};
      });

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final bookmarks = provider.bookmarks;
    final list = _filter(provider.restaurants, bookmarks);
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Padding(
            padding: EdgeInsets.fromLTRB(20, safeTop + 16, 20, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(8), blurRadius: 8)
                      ],
                    ),
                    child: const Icon(Icons.chevron_left,
                        size: 20, color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '저장한 매장',
                    style: TextStyle(
                      fontFamily: 'OkDanDan',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: Color(0xFF5E8C4A),
                    ),
                  ),
                ),
                if (list.isNotEmpty || _editMode)
                  GestureDetector(
                    onTap: _editMode ? _exitEdit : _enterEdit,
                    child: Text(
                      _editMode ? '완료' : '편집',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 필터 (편집 모드 아닐 때)
          if (!_editMode) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: _sortBy,
                      active: _sortBy != '최신순',
                      open: _openDropdown == 'sort',
                      onTap: () => setState(() =>
                          _openDropdown = _openDropdown == 'sort' ? null : 'sort'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _isAll(_regions) || _regions.isEmpty
                          ? '구역'
                          : _regions.length == 1
                              ? _regions.first
                              : '${_regions.first} 외 ${_regions.length - 1}',
                      active: !_isAll(_regions) && _regions.isNotEmpty,
                      open: _openDropdown == 'region',
                      onTap: () => setState(() =>
                          _openDropdown =
                              _openDropdown == 'region' ? null : 'region'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _isAll(_cuisines) || _cuisines.isEmpty
                          ? '음식종류'
                          : _cuisines.length == 1
                              ? _cuisines.first
                              : '${_cuisines.first} 외 ${_cuisines.length - 1}',
                      active: !_isAll(_cuisines) && _cuisines.isNotEmpty,
                      open: _openDropdown == 'cuisine',
                      onTap: () => setState(() =>
                          _openDropdown =
                              _openDropdown == 'cuisine' ? null : 'cuisine'),
                    ),
                  ],
                ),
              ),
            ),
            if (_openDropdown != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(10), blurRadius: 8)
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: _openDropdown == 'sort'
                      ? _DropdownGrid(
                          items: _sortOpts,
                          selected: {_sortBy},
                          onSelect: (v) =>
                              setState(() {_sortBy = v; _openDropdown = null;}),
                        )
                      : _openDropdown == 'region'
                          ? _DropdownGrid(
                              items: _regionOpts,
                              selected: _regions,
                              multiSelect: true,
                              onSelect: (v) => setState(() => _toggleFilter(_regions, v)),
                              onReset: () => setState(() {
                                _regions.clear();
                                _regions.add(_allLabel);
                              }),
                            )
                          : _DropdownGrid(
                              items: _cuisineOpts,
                              selected: _cuisines,
                              multiSelect: true,
                              onSelect: (v) => setState(() => _toggleFilter(_cuisines, v)),
                              onReset: () => setState(() {
                                _cuisines.clear();
                                _cuisines.add(_allLabel);
                              }),
                            ),
                ),
              ),
          ],

          // 목록
          Expanded(
            child: provider.restaurantsLoading && provider.restaurants.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF9ECA8B)),
                  )
                : list.isEmpty
                    ? bookmarks.isEmpty
                        ? const Center(
                            child: Text(
                              '저장한 매장이 없어요',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD1D5DB)),
                            ),
                          )
                        : provider.restaurantsLoadFailed
                            ? LoadErrorView(
                                onRetry: () => provider.refreshRestaurants(),
                              )
                            : const Center(
                                child: Text(
                                  '조건에 맞는 매장이 없어요',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD1D5DB)),
                                ),
                              )
                    : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = list[i];
                      return Row(
                        children: [
                          if (_editMode) ...[
                            GestureDetector(
                              onTap: () => _toggleSelect(r.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: _selectedIds.contains(r.id)
                                      ? const Color(0xFF9ECA8B)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedIds.contains(r.id)
                                        ? const Color(0xFF9ECA8B)
                                        : const Color(0xFFD1D5DB),
                                    width: 2,
                                  ),
                                ),
                                child: _selectedIds.contains(r.id)
                                    ? const Icon(Icons.check,
                                        size: 14, color: Color(0xFF111827))
                                    : null,
                              ),
                            ),
                          ],
                          Expanded(
                            child: RestaurantCard(
                              restaurant: r,
                              onTap: _editMode
                                  ? () => _toggleSelect(r.id)
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              DetailScreen(restaurant: r))),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // 편집 모드 하단 바
          if (_editMode)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, safeBottom + 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        for (final r in list) {
                          context.read<AppProvider>().toggleBookmark(r.id);
                        }
                        setState(() => _selectedIds = {});
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            '전체삭제',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF374151)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectedIds.isEmpty
                          ? null
                          : () {
                              for (final id in _selectedIds) {
                                context
                                    .read<AppProvider>()
                                    .toggleBookmark(id);
                              }
                              setState(() => _selectedIds = {});
                            },
                      child: AnimatedOpacity(
                        opacity: _selectedIds.isEmpty ? 0.3 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9ECA8B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _selectedIds.isEmpty
                                  ? '선택삭제'
                                  : '선택삭제 (${_selectedIds.length})',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool open;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.active,
      required this.open,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final on = active || open;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF9ECA8B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: on ? const Color(0xFF111827) : const Color(0xFF374151)),
            ),
            const SizedBox(width: 4),
            Icon(
              open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 12,
              color: on ? const Color(0xFF111827) : const Color(0xFF374151),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownGrid extends StatelessWidget {
  final List<String> items;
  final Set<String> selected;
  final bool multiSelect;
  final ValueChanged<String> onSelect;
  final VoidCallback? onReset;
  final String Function(String)? labelFor;
  final bool forceFourColumns;

  const _DropdownGrid({
    required this.items,
    required this.selected,
    this.multiSelect = false,
    required this.onSelect,
    this.onReset,
    this.labelFor,
    this.forceFourColumns = false,
  });

  static bool _isAllSelected(Set<String> s) =>
      s.length == 1 && s.contains('전체');

  @override
  Widget build(BuildContext context) {
    const spacing = 6.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (multiSelect && selected.isNotEmpty && !_isAllSelected(selected))
          GestureDetector(
            onTap: onReset,
            child: const Padding(
              padding: EdgeInsets.only(top: 4, right: 4, bottom: 8),
              child: Text('초기화',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5E8C4A))),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = forceFourColumns ? 4 : (items.length <= 3 ? items.length : 4);
            final itemWidth =
                (constraints.maxWidth - spacing * (cols - 1)) / cols;

            return SizedBox(
              width: constraints.maxWidth,
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: items.map((opt) {
                  final on = selected.contains(opt);
                  return SizedBox(
                    width: itemWidth,
                    child: GestureDetector(
                      onTap: () => onSelect(opt),
                      child: Container(
                        decoration: BoxDecoration(
                          color: on ? const Color(0xFFF3F8F0) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                labelFor != null ? labelFor!(opt) : opt,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: on
                                      ? const Color(0xFF5E8C4A)
                                      : const Color(0xFF374151),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (on)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.check,
                                    size: 14, color: Color(0xFF5E8C4A)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}
