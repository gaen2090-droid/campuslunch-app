import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/load_error_view.dart';
import '../widgets/restaurant_card.dart';
import 'home_screen.dart'
    show
        HomeFilterIconButton,
        HomeFilterSheet,
        HomeFilterChip,
        SimpleFilterSheet;
import 'detail_screen.dart';
import 'location_permission_screen.dart';

class BookmarkListScreen extends StatefulWidget {
  const BookmarkListScreen({super.key});

  @override
  State<BookmarkListScreen> createState() => _BookmarkListScreenState();
}

class _BookmarkListScreenState extends State<BookmarkListScreen> {
  static const _allLabel = '전체';
  static const _modeKey = 'bookmark';
  String _sortBy = '최신순';
  Set<String> _regions = {_allLabel};
  Set<String> _cuisines = {_allLabel};
  bool _filterLoaded = false;
  bool _editMode = false;
  Set<String> _selectedIds = {};

  static const _sortOpts = ['최신순', '인기순', '가까운순'];
  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [_allLabel, '한식', '중식', '일식', '양식', '아시아', '분식'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filterLoaded) {
      _filterLoaded = true;
      final p = context.read<AppProvider>();
      _sortBy = p.listFilterSortBy(_modeKey);
      _regions = Set.from(p.listFilterRegions(_modeKey));
      _cuisines = Set.from(p.listFilterCuisines(_modeKey));
    }
  }

  void _saveFilter() {
    context.read<AppProvider>().setListFilter(
      _modeKey,
      sortBy: _sortBy,
      regions: Set.from(_regions),
      cuisines: Set.from(_cuisines),
    );
  }

  bool _isAll(Set<String> s) => s.contains(_allLabel) && s.length == 1;

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
      return b.id.compareTo(a.id);
    });
    return list;
  }

  void _enterEdit() => setState(() {
        _editMode = true;
        _selectedIds = {};
      });

  void _exitEdit() => setState(() {
        _editMode = false;
        _selectedIds = {};
      });

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
      });

  void _openSimpleSheet({
    required String title,
    required List<String> items,
    required Set<String> selected,
    required bool multiSelect,
    required void Function(Set<String>) onApply,
    required VoidCallback onReset,
    required bool isActive,
  }) {
    final locationMode = context.read<AppProvider>().locationMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SimpleFilterSheet(
        title: title,
        items: items,
        selected: selected,
        multiSelect: multiSelect,
        isActive: isActive,
        locationMode: locationMode,
        onApply: onApply,
        onReset: onReset,
        onRequestLocation: () => showLocationPermissionDialog(context, onGranted: () {
          setState(() => _sortBy = '가까운순');
          _saveFilter();
        }),
      ),
    );
  }

  void _openFilterSheet(bool locationMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeFilterSheet(
        sortBy: _sortBy,
        regions: Set.from(_regions),
        cuisines: Set.from(_cuisines),
        locationMode: locationMode,
        onApply: (sortBy, regions, cuisines) {
          setState(() {
            _sortBy = sortBy;
            _regions = regions;
            _cuisines = cuisines;
          });
          _saveFilter();
        },
        onRequestLocation: () {
          showLocationPermissionDialog(context, onGranted: () {
            setState(() => _sortBy = '가까운순');
            _saveFilter();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final locationMode = provider.locationMode;
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
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: Color(0xFF111827)),
                ),
                const SizedBox(width: 19),
                const Expanded(
                  child: Text(
                    '즐겨찾기한 매장',
                    style: TextStyle(
                      fontFamily: 'OkDanDan',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Color(0xFF111827),
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
          if (!_editMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    HomeFilterIconButton(
                      active: _sortBy != '최신순' ||
                          (!_isAll(_regions) && _regions.isNotEmpty) ||
                          (!_isAll(_cuisines) && _cuisines.isNotEmpty),
                      onTap: () => _openFilterSheet(locationMode),
                    ),
                    const SizedBox(width: 8),
                    if (_sortBy != '최신순' ||
                        (!_isAll(_regions) && _regions.isNotEmpty) ||
                        (!_isAll(_cuisines) && _cuisines.isNotEmpty)) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _sortBy = '최신순';
                            _regions = {_allLabel};
                            _cuisines = {_allLabel};
                          });
                          _saveFilter();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF374151)),
                              SizedBox(width: 4),
                              Text('초기화',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF374151))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    HomeFilterChip(
                      label: _sortBy,
                      active: _sortBy != '최신순',
                      open: false,
                      onTap: () => _openSimpleSheet(
                        title: '정렬',
                        items: _sortOpts,
                        selected: {_sortBy},
                        multiSelect: false,
                        onApply: (v) { setState(() => _sortBy = v.first); _saveFilter(); },
                        onReset: () { setState(() => _sortBy = '최신순'); _saveFilter(); },
                        isActive: _sortBy != '최신순',
                      ),
                    ),
                    const SizedBox(width: 8),
                    HomeFilterChip(
                      label: _isAll(_regions) || _regions.isEmpty
                          ? '위치'
                          : _regions.length == 1
                              ? _regions.first
                              : '${_regions.first} 외 ${_regions.length - 1}',
                      active: !_isAll(_regions) && _regions.isNotEmpty,
                      open: false,
                      onTap: () => _openSimpleSheet(
                        title: '위치',
                        items: _regionOpts,
                        selected: Set.from(_regions),
                        multiSelect: true,
                        onApply: (v) { setState(() => _regions = v); _saveFilter(); },
                        onReset: () { setState(() => _regions = {_allLabel}); _saveFilter(); },
                        isActive: !_isAll(_regions),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HomeFilterChip(
                      label: _isAll(_cuisines) || _cuisines.isEmpty
                          ? '음식종류'
                          : _cuisines.length == 1
                              ? _cuisines.first
                              : '${_cuisines.first} 외 ${_cuisines.length - 1}',
                      active: !_isAll(_cuisines) && _cuisines.isNotEmpty,
                      open: false,
                      onTap: () => _openSimpleSheet(
                        title: '음식종류',
                        items: _cuisineOpts,
                        selected: Set.from(_cuisines),
                        multiSelect: true,
                        onApply: (v) { setState(() => _cuisines = v); _saveFilter(); },
                        onReset: () { setState(() => _cuisines = {_allLabel}); _saveFilter(); },
                        isActive: !_isAll(_cuisines),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                              '즐겨찾기한 매장이 없어요',
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
