import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/available_restaurant_ranking.dart';
import '../utils/business_hours.dart';
import '../utils/restaurant_sort.dart';
import '../widgets/load_error_view.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/report_sheet.dart';
import '../utils/report_feedback.dart';
import 'home_screen.dart'
    show
        NeedsReportCard,
        HomeFilterIconButton,
        HomeFilterSheet,
        HomeFilterChip,
        SimpleFilterSheet;
import 'detail_screen.dart';
import 'location_permission_screen.dart';

enum RestaurantListMode { available, slightlyBusy, stamp, busy, closed }

class RestaurantListScreen extends StatefulWidget {
  final RestaurantListMode mode;
  final int mainTab; // 0: 식당, 1: 카페

  const RestaurantListScreen({super.key, required this.mode, this.mainTab = 0});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  static const _allLabel = '전체';
  String _sortBy = '최신순';
  Set<String> _regions = {'전체'};
  Set<String> _cuisines = {'전체'};
  bool _bookmarkOnly = false;
  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [_allLabel, '한식', '중식', '일식', '양식', '아시아', '분식'];
  static const _sortOpts = ['최신순', '인기순', '가까운순'];


  String get _modeKey => widget.mode.name;

  bool _filterLoaded = false;

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

  List<Restaurant> _applyFilter(List<Restaurant> all) {
    final bookmarks = context.read<AppProvider>().bookmarks;
    return all.where((r) {
      final tabOk = widget.mainTab == 1 ? r.category == '카페' : r.category != '카페';
      final regionOk = _regions.contains(_allLabel) || _regions.contains(r.area);
      final cuisineOk = _cuisines.contains(_allLabel) || _cuisines.contains(r.category);
      final bookmarkOk = !_bookmarkOnly || bookmarks.contains(r.id);
      return tabOk && regionOk && cuisineOk && bookmarkOk;
    }).toList();
  }

  void _openSimpleSheet({
    required String title,
    required List<String> items,
    required Set<String> selected,
    required bool multiSelect,
    required void Function(Set<String>) onApply,
    required VoidCallback onReset,
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
        isActive: false,
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

  void _openDetail(Restaurant r) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)));

  void _openReport(Restaurant r) {
    if (r.status == '영업안함') return;
    ReportSheet.show(context, r, (status) {
      submitCrowdReportFeedback(context, r.id, status);
    });
  }

  List<Restaurant> _getSectionList(List<Restaurant> filtered, AppProvider provider) {
    bool isBusyStatus(Restaurant r) => r.status == '자리없음';

    switch (widget.mode) {
      case RestaurantListMode.available:
        final openWithReport = filtered
            .where((r) => r.status == '여유로움' && r.hasCrowdUpdate)
            .toList();
        return _sortSection(openWithReport, provider);
      case RestaurantListMode.slightlyBusy:
        return _sortSection(
          filtered.where((r) => r.status == '약간혼잡' && r.hasCrowdUpdate).toList(),
          provider,
        );
      case RestaurantListMode.stamp:
        return filtered.where((r) => r.status != '영업안함' && !r.hasCrowdUpdate).toList();
      case RestaurantListMode.busy:
        return _sortSection(
          filtered.where((r) => isBusyStatus(r) && r.hasCrowdUpdate).toList(),
          provider,
          isBusy: true,
        );
      case RestaurantListMode.closed:
        return _sortSection(
          filtered.where((r) => r.status == '영업안함').toList(),
          provider,
          isClosed: true,
        );
    }
  }

  List<Restaurant> _sortSection(List<Restaurant> list, AppProvider provider,
      {bool isClosed = false, bool isBusy = false}) {
    final useAlgo = provider.useAlgorithmRanking;
    int pop(Restaurant r) => popularityScore(r, useAlgo);
    final now = DateTime.now();
    final sorted = List<Restaurant>.from(list);
    sorted.sort((a, b) {
      if (_sortBy == '인기순') {
        final pd = pop(b).compareTo(pop(a));
        if (pd != 0) return pd;
        return a.updated.compareTo(b.updated);
      }
      if (_sortBy == '가까운순') {
        final dd = a.distance.compareTo(b.distance);
        if (dd != 0) return dd;
        if (isClosed) return 0;
        return a.updated.compareTo(b.updated);
      }
      // 최신순
      if (isClosed) {
        final am = BusinessHoursData(hoursCanonical: a.hours).minutesUntilNextOpen(now);
        final bm = BusinessHoursData(hoursCanonical: b.hours).minutesUntilNextOpen(now);
        if (am != bm) return am.compareTo(bm);
        return pop(b).compareTo(pop(a));
      }
      if (isBusy) {
        final ag = busyLatestGroup(a);
        final bg = busyLatestGroup(b);
        if (ag != bg) return ag.compareTo(bg);
      }
      final ud = a.updated.compareTo(b.updated);
      if (ud != 0) return ud;
      return pop(b).compareTo(pop(a));
    });
    return sorted;
  }

  String get _title {
    switch (widget.mode) {
      case RestaurantListMode.available: return '바로 입장 가능해요';
      case RestaurantListMode.slightlyBusy: return '빈자리 조금 있어요';
      case RestaurantListMode.stamp: return '혼잡도를 알려주세요';
      case RestaurantListMode.busy: return '붐비고 있어요';
      case RestaurantListMode.closed: return '영업이 종료됐어요';
    }
  }

  Color get _dotColor {
    switch (widget.mode) {
      case RestaurantListMode.available: return const Color(0xFF4C9C2A);
      case RestaurantListMode.slightlyBusy: return const Color(0xFFF59E0B);
      case RestaurantListMode.stamp: return const Color(0xFF111827);
      case RestaurantListMode.busy: return const Color(0xFFEF4444);
      case RestaurantListMode.closed: return const Color(0xFF9CA3AF);
    }
  }

  Color get _titleColor {
    switch (widget.mode) {
      case RestaurantListMode.closed: return const Color(0xFF9CA3AF);
      default: return const Color(0xFF111827);
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final locationMode = provider.locationMode;
    final filtered = _applyFilter(provider.restaurants);
    final list = _getSectionList(filtered, provider);

    Restaurant? recommended;
    if (widget.mode == RestaurantListMode.available) {
      recommended = buildAvailableSection(filtered, provider.useAlgorithmRanking).recommended;
    }
    final cards = recommended == null
        ? list
        : list.where((r) => r.id != recommended!.id).toList();

    final loading = provider.restaurantsLoading;
    final loadFailed = provider.restaurantsLoadFailed;

    final hasFilter = _sortBy != '최신순' ||
        (!_isAll(_regions) && _regions.isNotEmpty) ||
        (!_isAll(_cuisines) && _cuisines.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              // ── 헤더 ──
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뒤로가기 + 타이틀
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 18, color: Color(0xFF111827)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: _dotColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(_title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        color: _titleColor)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 필터 칩
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          HomeFilterIconButton(
                            active: hasFilter,
                            onTap: () => _openFilterSheet(locationMode),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() => _bookmarkOnly = !_bookmarkOnly);
                              _saveFilter();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _bookmarkOnly ? const Color(0xFF111827) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _bookmarkOnly ? const Color(0xFF111827) : const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '즐겨찾기',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: _bookmarkOnly ? Colors.white : const Color(0xFF374151)),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    _bookmarkOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    size: 14,
                                    color: _bookmarkOnly ? Colors.white : const Color(0xFF111827),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (hasFilter) ...[
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 콘텐츠 ──
              Expanded(
                child: RefreshIndicator(
                    color: const Color(0xFF111827),
                    onRefresh: () => provider.refreshRestaurants(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
                      children: [
                        if (widget.mode == RestaurantListMode.available) ...[
                          if (recommended != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              child: HeroRestaurantCard(
                                restaurant: recommended,
                                onDetail: () => _openDetail(recommended!),
                                onReport: () => _openReport(recommended!),
                              ),
                            ),
                          ...cards.map((r) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 10),
                                child: RestaurantCard(
                                    restaurant: r,
                                    onTap: () => _openDetail(r)),
                              )),
                        ] else if (widget.mode == RestaurantListMode.stamp)
                          ...list.map((r) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 10),
                                child: NeedsReportCard(
                                    restaurant: r,
                                    onTap: () => _openDetail(r)),
                              ))
                        else
                          ...list.map((r) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 10),
                                child: RestaurantCard(
                                    restaurant: r,
                                    onTap: () => _openDetail(r)),
                              )),

                        if (list.isEmpty &&
                            (widget.mode != RestaurantListMode.available ||
                                recommended == null))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                            child: Center(
                              child: loading
                                  ? const CircularProgressIndicator(
                                      color: Color(0xFF111827))
                                  : loadFailed
                                      ? LoadErrorView(
                                          onRetry: () =>
                                              provider.refreshRestaurants())
                                      : const Text('표시할 매장이 없어요.',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF9CA3AF))),
                            ),
                          ),
                      ],
                    ),
                  ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
