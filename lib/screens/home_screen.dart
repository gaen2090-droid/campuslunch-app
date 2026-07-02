import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/load_error_view.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_image.dart';
import '../widgets/rice_ball_icon.dart';
import '../utils/available_restaurant_ranking.dart';
import '../utils/business_hours.dart';
import '../utils/restaurant_sort.dart';
import '../utils/report_feedback.dart';
import '../widgets/report_sheet.dart';
import 'bookmark_list_screen.dart';
import 'detail_screen.dart';
import 'location_permission_screen.dart';
import 'restaurant_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _allLabel = '전체';
  String _sortBy = '최신순';
  Set<String> _regions = {'전체'};
  Set<String> _cuisines = {'전체'};
  String? _openDropdown; // 'sort' | 'region' | 'cuisine' | null
  bool _searchActive = false;
  String? _lastBannerImpressionId;
  final _searchCtrl = TextEditingController();
  final _crowdInfoOverlay = OverlayPortalController();
  final _crowdInfoLink = LayerLink();
  final _crowdInfoOverlay2 = OverlayPortalController();
  final _crowdInfoLink2 = LayerLink();
  final _crowdInfoOverlay3 = OverlayPortalController();
  final _crowdInfoLink3 = LayerLink();
  final _stampInfoOverlay = OverlayPortalController();
  final _stampInfoLink = LayerLink();

  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [_allLabel, '한식', '중식', '일식', '양식', '아시아', '분식', '카페'];
  static const _sortOpts = ['최신순', '인기순', '가까운순', '여유로운순'];

  bool _filterLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filterLoaded) {
      _filterLoaded = true;
      final p = context.read<AppProvider>();
      _sortBy = p.homeFilterSortBy;
      _regions = Set.from(p.homeFilterRegions);
      _cuisines = Set.from(p.homeFilterCuisines);
    }
  }

  void _saveFilter() {
    context.read<AppProvider>().setHomeFilter(
      sortBy: _sortBy,
      regions: Set.from(_regions),
      cuisines: Set.from(_cuisines),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Restaurant> _filter(List<Restaurant> all) {
    return all.where((r) {
      final regionOk = _regions.contains(_allLabel) || _regions.contains(r.area);
      final cuisineOk = _cuisines.contains(_allLabel) || _cuisines.contains(r.category);
      return regionOk && cuisineOk;
    }).toList();
  }

  // 섹션별 독립 정렬
  List<Restaurant> _sortSection(List<Restaurant> list, {bool isClosed = false, bool isBusy = false}) {
    final useAlgo = context.read<AppProvider>().useAlgorithmRanking;
    int pop(Restaurant r) => popularityScore(r, useAlgo);

    final sorted = List<Restaurant>.from(list);
    sorted.sort((a, b) {
      final now = DateTime.now();

      if (_sortBy == '인기순') {
        if (isClosed) return pop(b).compareTo(pop(a));
        // 바로입장가능/붐비는매장 공통: 인기순 → 최신순
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

      if (_sortBy == '여유로운순') {
        if (isClosed) {
          final am = BusinessHoursData(hoursCanonical: a.hours).minutesUntilNextOpen(now);
          final bm = BusinessHoursData(hoursCanonical: b.hours).minutesUntilNextOpen(now);
          if (am != bm) return am.compareTo(bm);
          return pop(b).compareTo(pop(a));
        }
        // 바로입장가능: 여유로움→약간혼잡 / 붐비는매장: 자리없음→웨이팅많음 → 최신순 → 인기순
        final sd = isBusy
            ? busySortStatusPriority(a.status) - busySortStatusPriority(b.status)
            : availableSortStatusPriority(a.status) - availableSortStatusPriority(b.status);
        if (sd != 0) return sd;
        final ud = a.updated.compareTo(b.updated);
        if (ud != 0) return ud;
        return pop(b).compareTo(pop(a));
      }

      // 최신순
      if (isClosed) {
        final am = BusinessHoursData(hoursCanonical: a.hours).minutesUntilNextOpen(now);
        final bm = BusinessHoursData(hoursCanonical: b.hours).minutesUntilNextOpen(now);
        if (am != bm) return am.compareTo(bm);
        return pop(b).compareTo(pop(a));
      }

      final ag = isBusy ? busyLatestGroup(a) : availableLatestGroup(a);
      final bg = isBusy ? busyLatestGroup(b) : availableLatestGroup(b);
      if (ag != bg) return ag.compareTo(bg);
      final updatedD = a.updated.compareTo(b.updated);
      if (updatedD != 0) return updatedD;
      return pop(b).compareTo(pop(a));
    });
    return sorted;
  }

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

List<Restaurant> _search(List<Restaurant> all, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return [];
    return all
        .where((r) => '${r.name} ${r.area} ${r.category}'.toLowerCase().contains(query))
        .toList();
  }

  void _openDetail(Restaurant r) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)));

  void _openRecommendedDetail(Restaurant r) {
    context.read<AppProvider>().recordBannerClick(r.id);
    _openDetail(r);
  }

  void _trackBannerImpression(Restaurant? recommended) {
    if (recommended == null) return;
    if (_lastBannerImpressionId == recommended.id) return;
    _lastBannerImpressionId = recommended.id;
    context.read<AppProvider>().recordBannerImpression(recommended.id);
  }

  void _openSimpleSheet({
    required String title,
    required List<String> items,
    required Set<String> selected,
    required bool multiSelect,
    required void Function(Set<String>) onApply,
    required VoidCallback onReset,
    required bool isActive,
  }) {
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
        locationMode: context.read<AppProvider>().locationMode,
        onApply: onApply,
        onReset: onReset,
        onRequestLocation: () => showLocationPermissionDialog(context, onGranted: () {
          setState(() => _sortBy = '가까운순');
          _saveFilter();
        }),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeFilterSheet(
        sortBy: _sortBy,
        regions: Set.from(_regions),
        cuisines: Set.from(_cuisines),
        locationMode: context.read<AppProvider>().locationMode,
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

  void _openReport(Restaurant r) {
    if (r.status == '영업안함') return;
    ReportSheet.show(context, r, (status) {
      submitCrowdReportFeedback(context, r.id, status);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final locationMode = provider.locationMode;
    final all = provider.restaurants;
    final filtered = _filter(all);
    final searchResults = _search(all, _searchCtrl.text);

    bool isBusyStatus(Restaurant r) => r.status == '자리없음' || r.status == '웨이팅많음';

    final recommended = buildAvailableSection(filtered, provider.useAlgorithmRanking).recommended;

    _trackBannerImpression(recommended);

    const _sectionMaxMinutes = 30;

    final availableListRecent = _sortSection(
      filtered.where((r) => r.status != '영업안함' && !isBusyStatus(r) && r.hasCrowdUpdate && r.updated <= _sectionMaxMinutes).toList(),
    );
    final availableListAll = _sortSection(
      filtered.where((r) => r.status != '영업안함' && !isBusyStatus(r) && r.hasCrowdUpdate).toList(),
    );
    final availableStale = availableListRecent.isEmpty && availableListAll.isNotEmpty;
    final availableList = availableStale ? availableListAll : availableListRecent;

    // 배너용: 10분 이내만
    final recentAvailable = availableListRecent.where((r) => r.updated <= 10).toList();
    // 섹션 카드용: 추천 배너 제외
    final availableCards = recommended == null
        ? availableList
        : availableList.where((r) => r.id != recommended.id).toList();
    // 더보기 판단용
    final recentCards = recommended == null
        ? recentAvailable
        : recentAvailable.where((r) => r.id != recommended.id).toList();

    final slightlyBusyListRecent = _sortSection(
      filtered.where((r) => r.status == '약간혼잡' && r.hasCrowdUpdate && r.updated <= _sectionMaxMinutes).toList(),
    );
    final slightlyBusyListAll = _sortSection(
      filtered.where((r) => r.status == '약간혼잡' && r.hasCrowdUpdate).toList(),
    );
    final slightlyBusyStale = slightlyBusyListRecent.isEmpty && slightlyBusyListAll.isNotEmpty;
    final slightlyBusyList = slightlyBusyStale ? slightlyBusyListAll : slightlyBusyListRecent;

    final stampList = filtered
        .where((r) => r.status != '영업안함' && !r.hasCrowdUpdate)
        .toList();

    final busyListRecent = _sortSection(
      filtered.where((r) => isBusyStatus(r) && r.hasCrowdUpdate && r.updated <= _sectionMaxMinutes).toList(),
      isBusy: true,
    );
    final busyListAll = _sortSection(
      filtered.where((r) => isBusyStatus(r) && r.hasCrowdUpdate).toList(),
      isBusy: true,
    );
    final busyStale = busyListRecent.isEmpty && busyListAll.isNotEmpty;
    final busyList = busyStale ? busyListAll : busyListRecent;
    final closedList = all
        .where((r) => r.status == '영업안함')
        .toList();

    final countClosed = closedList.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
        // ── 헤더 ──
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 검색 바
              Row(
                children: [
                  if (!_searchActive)
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9ECA8B),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Center(
                          child: RiceBallIcon(size: 22)),
                    ),
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
                          const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onTap: () => setState(() => _searchActive = true),
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1F2937)),
                              decoration: const InputDecoration(
                                hintText: '매장명, 위치, 음식종류 검색',
                                hintStyle: TextStyle(
                                    fontSize: 14, color: Color(0xFF9CA3AF)),
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
                                child: Icon(Icons.close,
                                    size: 16, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_searchActive) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() {
                        _searchActive = false;
                        _searchCtrl.clear();
                        _openDropdown = null;
                      }),
                      child: const Text('취소',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6B7280))),
                    ),
                  ] else ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookmarkListScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(Icons.bookmark_rounded,
                              size: 20, color: Color(0xFF5E8C4A)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              if (!_searchActive) ...[
                const SizedBox(height: 12),
                // 필터 칩
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      HomeFilterIconButton(
                        active: _sortBy != '최신순' ||
                            (!_isAll(_regions) && _regions.isNotEmpty) ||
                            (!_isAll(_cuisines) && _cuisines.isNotEmpty),
                        onTap: () {
                          setState(() => _openDropdown = null);
                          _openFilterSheet();
                        },
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
                      const SizedBox(width: 8),
                      HomeCafeFilterChip(
                        active: _cuisines.length == 1 && _cuisines.contains('카페'),
                        onTap: () {
                          setState(() {
                            if (_cuisines.length == 1 && _cuisines.contains('카페')) {
                              _cuisines = {_allLabel};
                            } else {
                              _cuisines = {'카페'};
                            }
                          });
                          _saveFilter();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── 콘텐츠 ──
        Expanded(
          child: _searchActive
              ? _buildSearch(searchResults)
              : _buildHome(
                  recommended: recommended,
                  recentCards: recentCards,
                  availableCards: availableCards,
                  loading: provider.restaurantsLoading,
                  loadFailed: provider.restaurantsLoadFailed,
                  availableList: availableList,
                  availableStale: availableStale,
                  slightlyBusyList: slightlyBusyList,
                  slightlyBusyStale: slightlyBusyStale,
                  stampList: stampList,
                  busyList: busyList,
                  busyStale: busyStale,
                  countClosed: countClosed,
                ),
        ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearch(List<Restaurant> results) {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      return const Center(
        child: Text('검색어를 입력해주세요.',
            style: TextStyle(
                fontFamily: 'OkDanDan',
                fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '검색 결과',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827)),
              ),
              Text(
                '${results.length}곳',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD1D5DB)),
              ),
            ],
          ),
        ),
        if (results.isEmpty)
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF5E8C4A),
              onRefresh: () => context.read<AppProvider>().refreshRestaurants(),
              child: ListView(
                children: [
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 80),
                      child: Text('검색 결과가 없어요.',
                          style: TextStyle(
                              fontFamily: 'OkDanDan',
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF5E8C4A),
              onRefresh: () => context.read<AppProvider>().refreshRestaurants(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => RestaurantCard(
                  restaurant: results[i],
                  onTap: () => _openDetail(results[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHome({
    required Restaurant? recommended,
    required List<Restaurant> recentCards,
    required List<Restaurant> availableCards,
    required bool loading,
    required bool loadFailed,
    required List<Restaurant> availableList,
    required bool availableStale,
    required List<Restaurant> slightlyBusyList,
    required bool slightlyBusyStale,
    required List<Restaurant> stampList,
    required List<Restaurant> busyList,
    required bool busyStale,
    required int countClosed,
  }) {
    void goTo(RestaurantListMode mode) => Navigator.push(
          context, MaterialPageRoute(builder: (_) => RestaurantListScreen(mode: mode)));

    final hasAvailable = recommended != null || availableCards.isNotEmpty;
    final top5Available = availableCards.take(availableStale ? (recommended != null ? 0 : 1) : 10).toList();
    final top5SlightlyBusy = slightlyBusyList.take(slightlyBusyStale ? 1 : 10).toList();
    final stampCards = stampList.take(5).toList();
    final busyCards = busyList.take(5).toList();

    const emptyMsg = '최근 제보된 매장이 없어요. 제보하고 스탬프를 받아보세요!';

    Widget crowdBadge(String label, Color bg, Color fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: fg)),
        );

    Widget sectionHeader({
      required String title,
      required Color dotColor,
      required VoidCallback onMore,
      Widget? trailing,
      String? subText,
    }) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'OkDanDan',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827))),
                  ],
                ),
                if (subText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 16),
                    child: Text(subText,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF))),
                  ),
              ],
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    Widget moreButton(VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Text('더보기',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF))),
            ),
          ),
        );

    Widget emptyCard() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: Text(emptyMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF))),
          ),
        );

    return GestureDetector(
      onTap: () { if (_openDropdown != null) setState(() => _openDropdown = null); },
      child: RefreshIndicator(
        color: const Color(0xFF5E8C4A),
        onRefresh: () => context.read<AppProvider>().refreshRestaurants(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
          children: [
            // 로딩/에러
            if (loading || loadFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                child: Center(
                  child: loading
                      ? const CircularProgressIndicator(color: Color(0xFF9ECA8B))
                      : LoadErrorView(
                          onRetry: () => context.read<AppProvider>().refreshRestaurants()),
                ),
              ),

            // ── 바로 입장 가능해요 ──
            sectionHeader(
              title: '바로 입장 가능해요',
              dotColor: const Color(0xFF4C9C2A),
              onMore: () => goTo(RestaurantListMode.available),
              subText: availableStale ? '최근 제보가 없어요' : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompositedTransformTarget(
                    link: _crowdInfoLink,
                    child: OverlayPortal(
                      controller: _crowdInfoOverlay,
                      overlayChildBuilder: (context) => CrowdLevelInfoPopup(
                        link: _crowdInfoLink,
                        onDismiss: _crowdInfoOverlay.hide,
                      ),
                      child: GestureDetector(
                        onTap: _crowdInfoOverlay.toggle,
                        child: const Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  crowdBadge('여유로움', const Color(0xFFDAFFCA), const Color(0xFF4C9C2A)),
                ],
              ),
            ),
            if (!hasAvailable)
              emptyCard()
            else ...[
              if (recommended != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: HeroRestaurantCard(
                    restaurant: recommended,
                    onDetail: () => _openRecommendedDetail(recommended),
                    onReport: () => _openReport(recommended),
                  ),
                ),
              ...top5Available.map((r) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: RestaurantCard(restaurant: r, onTap: () => _openDetail(r)),
                  )),
              moreButton(() => goTo(RestaurantListMode.available)),
            ],

            // ── 빈자리 조금 있어요 ──
            sectionHeader(
              title: '빈자리 조금 있어요',
              dotColor: const Color(0xFFF59E0B),
              onMore: () => goTo(RestaurantListMode.slightlyBusy),
              subText: slightlyBusyStale ? '최근 제보가 없어요' : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompositedTransformTarget(
                    link: _crowdInfoLink2,
                    child: OverlayPortal(
                      controller: _crowdInfoOverlay2,
                      overlayChildBuilder: (context) => CrowdLevelInfoPopup(
                        link: _crowdInfoLink2,
                        onDismiss: _crowdInfoOverlay2.hide,
                      ),
                      child: GestureDetector(
                        onTap: _crowdInfoOverlay2.toggle,
                        child: const Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  crowdBadge('약간혼잡', const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
                ],
              ),
            ),
            if (slightlyBusyList.isEmpty)
              emptyCard()
            else ...[
              ...top5SlightlyBusy.map((r) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: RestaurantCard(restaurant: r, onTap: () => _openDetail(r)),
                  )),
              moreButton(() => goTo(RestaurantListMode.slightlyBusy)),
            ],

            // ── 혼잡도를 알려주세요 (매장 있을 때만) ──
            if (stampList.isNotEmpty) ...[
              sectionHeader(
                title: '혼잡도를 알려주세요',
                dotColor: const Color(0xFF111827),
                onMore: () => goTo(RestaurantListMode.stamp),
                trailing: CompositedTransformTarget(
                  link: _stampInfoLink,
                  child: OverlayPortal(
                    controller: _stampInfoOverlay,
                    overlayChildBuilder: (context) => StampInfoPopup(
                      link: _stampInfoLink,
                      onDismiss: _stampInfoOverlay.hide,
                    ),
                    child: GestureDetector(
                      onTap: _stampInfoOverlay.toggle,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 4),
                          Text('스탬프',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ...stampCards.map((r) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: NeedsReportCard(restaurant: r, onTap: () => _openDetail(r)),
                  )),
              moreButton(() => goTo(RestaurantListMode.stamp)),
            ],

            // ── 붐비고 있어요 ──
            sectionHeader(
              title: '붐비고 있어요',
              dotColor: const Color(0xFFEF4444),
              onMore: () => goTo(RestaurantListMode.busy),
              subText: busyStale ? '최근 제보가 없어요' : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompositedTransformTarget(
                    link: _crowdInfoLink3,
                    child: OverlayPortal(
                      controller: _crowdInfoOverlay3,
                      overlayChildBuilder: (context) => CrowdLevelInfoPopup(
                        link: _crowdInfoLink3,
                        onDismiss: _crowdInfoOverlay3.hide,
                      ),
                      child: GestureDetector(
                        onTap: _crowdInfoOverlay3.toggle,
                        child: const Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  crowdBadge('자리없음', const Color(0xFFFFEDD5), const Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  crowdBadge('🔥웨이팅', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
                ],
              ),
            ),
            if (busyList.isEmpty)
              emptyCard()
            else ...[
              ...busyCards.map((r) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: RestaurantCard(restaurant: r, onTap: () => _openDetail(r)),
                  )),
              moreButton(() => goTo(RestaurantListMode.busy)),
            ],

            // ── 영업 종료 버튼 ──
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _SectionButton(
                label: '영업 종료',
                dotColor: const Color(0xFF9CA3AF),
                count: countClosed,
                hideDot: true,
                bgColor: const Color(0xFFF3F4F6),
                onTap: () => goTo(RestaurantListMode.closed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  final String label;
  final Color dotColor;
  final int count;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool highlighted;
  final bool hideDot;
  final Color? bgColor;

  const _SectionButton({
    required this.label,
    required this.dotColor,
    required this.count,
    required this.onTap,
    this.leadingIcon,
    this.leadingIconColor,
    this.highlighted = false,
    this.hideDot = false,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: bgColor ?? (highlighted ? const Color(0xFFF3F8F0) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: highlighted ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            if (!hideDot) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: leadingIcon != null
                    ? Icon(leadingIcon, size: 14, color: leadingIconColor ?? dotColor)
                    : Center(
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: 'OkDanDan',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: Color(0xFF111827))),
            ),
            Text('$count',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}

class CrowdLevelInfoPopup extends StatelessWidget {
  final LayerLink link;
  final VoidCallback onDismiss;
  const CrowdLevelInfoPopup({required this.link, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    const items = [
      CrowdLevelInfo(status: '여유로움', description: '바로 앉을 수 있어요'),
      CrowdLevelInfo(status: '약간혼잡', description: '빈자리 조금 있어요'),
      CrowdLevelInfo(status: '자리없음', description: '조금 기다려야 해요'),
      CrowdLevelInfo(status: '웨이팅많음', description: '웨이팅이 많아요'),
    ];

    return Stack(
      children: [
        // 바깥 영역 탭하면 닫힘
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 230,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '피크타임엔 매장 상황이 빠르게 바뀔 수 있어요.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  for (var idx = 0; idx < items.length; idx++)
                    Padding(
                      padding: EdgeInsets.only(bottom: idx == items.length - 1 ? 0 : 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadgePreview(status: items[idx].status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                items[idx].description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StampInfoPopup extends StatelessWidget {
  final LayerLink link;
  final VoidCallback onDismiss;
  const StampInfoPopup({required this.link, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    const lines = [
      '최초 제보 시 스탬프를 2개 받을 수 있어요.',
      '이외의 매장에 제보 시 스탬프를 1개 지급 받아요.',
      '단, 하루 최대 3개의 스탬프를 획득할 수 있어요.',
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 5, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lines[i],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CrowdLevelInfo {
  final String status;
  final String description;

  const CrowdLevelInfo({
    required this.status,
    required this.description,
  });
}

/// 홈화면 매장 카드 뱃지와 동일한 모양 (업데이트 시간 표시는 제외)
class StatusBadgePreview extends StatelessWidget {
  final String status;
  const StatusBadgePreview({required this.status});

  @override
  Widget build(BuildContext context) {
    final meta = crowdStatusMeta(status);
    final isHotWaiting = status == '웨이팅많음';
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Color(meta.bgColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: isHotWaiting
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 9)),
                  const SizedBox(width: 2),
                  Text(
                    '웨이팅',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(meta.color),
                    ),
                  ),
                ],
              )
            : Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(meta.color),
                ),
              ),
      ),
    );
  }
}

class NeedsReportCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;
  const NeedsReportCard({super.key, required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 48, height: 48,
                child: RestaurantImage(
                  url: r.imageUrl,
                  fallback: () => Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(color: Color(0xFF9ECA8B)),
                    child: const Center(
                      child: RiceBallIcon(size: 22),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.area == r.category ? r.area : '${r.area} · ${r.category}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '제보하면 스탬프 2개',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeFilterIconButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const HomeFilterIconButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF9ECA8B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded,
                size: 13,
                color: active ? const Color(0xFF111827) : const Color(0xFF374151)),
            const SizedBox(width: 5),
            Text(
              '필터',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: active ? const Color(0xFF111827) : const Color(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeFilterSheet extends StatefulWidget {
  final String sortBy;
  final Set<String> regions;
  final Set<String> cuisines;
  final bool locationMode;
  final void Function(String sortBy, Set<String> regions, Set<String> cuisines) onApply;
  final VoidCallback onRequestLocation;

  const HomeFilterSheet({
    required this.sortBy,
    required this.regions,
    required this.cuisines,
    required this.locationMode,
    required this.onApply,
    required this.onRequestLocation,
  });

  @override
  State<HomeFilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<HomeFilterSheet> {
  static const _allLabel = '전체';
  static const _sortOpts = ['최신순', '인기순', '가까운순', '여유로운순'];
  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [_allLabel, '한식', '중식', '일식', '양식', '아시아', '분식', '카페'];

  late String _sortBy;
  late Set<String> _regions;
  late Set<String> _cuisines;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _regions = Set.from(widget.regions);
    _cuisines = Set.from(widget.cuisines);
  }

  bool _isAll(Set<String> s) => s.contains(_allLabel) && s.length == 1;

  void _toggleMulti(Set<String> target, String value) {
    if (value == _allLabel) {
      target..clear()..add(_allLabel);
      return;
    }
    target.remove(_allLabel);
    target.contains(value) ? target.remove(value) : target.add(value);
    if (target.isEmpty) target.add(_allLabel);
  }

  bool get _hasActive =>
      _sortBy != '최신순' ||
      (!_isAll(_regions) && _regions.isNotEmpty) ||
      (!_isAll(_cuisines) && _cuisines.isNotEmpty);

  void _reset() => setState(() {
        _sortBy = '최신순';
        _regions = {_allLabel};
        _cuisines = {_allLabel};
      });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, safeBottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40, height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3)),
            ),
          ),
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('필터',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
              if (_hasActive)
                GestureDetector(
                  onTap: _reset,
                  child: const Text('초기화',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5E8C4A))),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 정렬
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('정렬',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6B7280))),
              if (_sortBy != '최신순')
                GestureDetector(
                  onTap: () => setState(() => _sortBy = '최신순'),
                  child: const Text('초기화',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF))),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sortOpts.map((opt) {
              final on = _sortBy == opt;
              return GestureDetector(
                onTap: () {
                  if (opt == '가까운순' && !widget.locationMode) {
                    Navigator.pop(context);
                    widget.onRequestLocation();
                    return;
                  }
                  setState(() => _sortBy = opt);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFF9ECA8B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: on ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(opt,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: on ? const Color(0xFF111827) : const Color(0xFF374151))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 위치
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('위치',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6B7280))),
              if (!_isAll(_regions))
                GestureDetector(
                  onTap: () => setState(() => _regions = {_allLabel}),
                  child: const Text('초기화',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF))),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _regionOpts.map((opt) {
              final on = _regions.contains(opt);
              return GestureDetector(
                onTap: () => setState(() => _toggleMulti(_regions, opt)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFF9ECA8B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: on ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(opt,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: on ? const Color(0xFF111827) : const Color(0xFF374151))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 음식종류
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('음식종류',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6B7280))),
              if (!_isAll(_cuisines))
                GestureDetector(
                  onTap: () => setState(() => _cuisines = {_allLabel}),
                  child: const Text('초기화',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF))),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cuisineOpts.map((opt) {
              final on = _cuisines.contains(opt);
              return GestureDetector(
                onTap: () => setState(() => _toggleMulti(_cuisines, opt)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFF9ECA8B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: on ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(opt,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: on ? const Color(0xFF111827) : const Color(0xFF374151))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // 적용 버튼
          GestureDetector(
            onTap: () {
              widget.onApply(_sortBy, _regions, _cuisines);
              Navigator.pop(context);
            },
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF9ECA8B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('적용하기',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeCafeFilterChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const HomeCafeFilterChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF9ECA8B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '카페만 보기',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: active ? const Color(0xFF111827) : const Color(0xFF374151)),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.coffee_rounded,
              size: 14,
              color: active ? const Color(0xFF111827) : const Color(0xFF5E8C4A),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool open;
  final VoidCallback onTap;

  const HomeFilterChip({
    required this.label,
    required this.active,
    required this.open,
    required this.onTap,
  });

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

class HomeDropdownGrid extends StatelessWidget {
  final List<String> items;
  final Set<String> selected;
  final bool multiSelect;
  final ValueChanged<String> onSelect;
  final VoidCallback? onReset;
  final bool showReset;

  const HomeDropdownGrid({
    required this.items,
    required this.selected,
    this.multiSelect = false,
    required this.onSelect,
    this.onReset,
    this.showReset = false,
  });

  static bool _isAllSelected(Set<String> s) =>
      s.length == 1 && s.contains('전체');

  @override
  Widget build(BuildContext context) {
    const spacing = 6.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = items.length <= 3 ? items.length : 4;
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
                                opt,
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
        if (showReset || (multiSelect && selected.isNotEmpty && !_isAllSelected(selected)))
          GestureDetector(
            onTap: onReset,
            child: const Padding(
              padding: EdgeInsets.only(top: 8, right: 4),
              child: Text('초기화',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5E8C4A))),
            ),
          ),
      ],
    );
  }
}

class SimpleFilterSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final Set<String> selected;
  final bool multiSelect;
  final bool isActive;
  final bool locationMode;
  final void Function(Set<String>) onApply;
  final VoidCallback onReset;
  final VoidCallback onRequestLocation;

  const SimpleFilterSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.multiSelect,
    required this.isActive,
    required this.locationMode,
    required this.onApply,
    required this.onReset,
    required this.onRequestLocation,
  });

  @override
  State<SimpleFilterSheet> createState() => _SimpleFilterSheetState();
}

class _SimpleFilterSheetState extends State<SimpleFilterSheet> {
  static const _allLabel = '전체';
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  void _toggle(String v) {
    if (!widget.multiSelect) {
      setState(() => _selected = {v});
      return;
    }
    if (v == _allLabel) {
      setState(() => _selected = {_allLabel});
      return;
    }
    setState(() {
      _selected.remove(_allLabel);
      _selected.contains(v) ? _selected.remove(v) : _selected.add(v);
      if (_selected.isEmpty) _selected.add(_allLabel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, safeBottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40, height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3)),
            ),
          ),
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
              if (!widget.multiSelect
                  ? !_selected.contains(widget.items.first)
                  : !(_selected.length == 1 && _selected.contains(_allLabel)))
                GestureDetector(
                  onTap: () {
                    setState(() => _selected = {widget.multiSelect ? _allLabel : widget.items.first});
                  },
                  child: const Text('초기화',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 옵션 리스트
          ...widget.items.map((opt) {
            final on = _selected.contains(opt);
            return GestureDetector(
              onTap: () {
                if (opt == '가까운순' && !widget.locationMode) {
                  Navigator.pop(context);
                  widget.onRequestLocation();
                  return;
                }
                if (!widget.multiSelect) {
                  widget.onApply({opt});
                  Navigator.pop(context);
                  return;
                }
                _toggle(opt);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(opt,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                              color: on ? const Color(0xFF111827) : const Color(0xFF6B7280))),
                    ),
                    if (on)
                      const Icon(Icons.check_rounded, size: 18, color: Color(0xFF5E8C4A)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 28),
          if (!widget.multiSelect)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('닫기',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6B7280))),
                ),
              ),
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      widget.onApply(_selected);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9ECA8B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('적용하기',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827))),
                      ),
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
