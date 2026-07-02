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
        CrowdLevelInfoPopup,
        StampInfoPopup,
        HomeFilterIconButton,
        HomeFilterSheet,
        HomeCafeFilterChip,
        HomeFilterChip,
        HomeDropdownGrid;
import 'detail_screen.dart';
import 'location_permission_screen.dart';

enum RestaurantListMode { available, stamp, busy, closed }

class RestaurantListScreen extends StatefulWidget {
  final RestaurantListMode mode;

  const RestaurantListScreen({super.key, required this.mode});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  static const _allLabel = '전체';
  String _sortBy = '최신순';
  Set<String> _regions = {_allLabel};
  Set<String> _cuisines = {_allLabel};
  String? _openDropdown;

  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [_allLabel, '한식', '중식', '일식', '양식', '아시아', '분식', '카페'];
  static const _sortOpts = ['최신순', '인기순', '가까운순', '여유로운순'];

  final _crowdInfoOverlay = OverlayPortalController();
  final _crowdInfoLink = LayerLink();
  final _stampInfoOverlay = OverlayPortalController();
  final _stampInfoLink = LayerLink();

  bool _isAll(Set<String> s) => s.contains(_allLabel) && s.length == 1;

  void _toggleFilter(Set<String> target, String value) {
    if (value == _allLabel) {
      target..clear()..add(_allLabel);
      return;
    }
    target.remove(_allLabel);
    target.contains(value) ? target.remove(value) : target.add(value);
    if (target.isEmpty) target.add(_allLabel);
  }

  List<Restaurant> _applyFilter(List<Restaurant> all) {
    return all.where((r) {
      final regionOk = _regions.contains(_allLabel) || _regions.contains(r.area);
      final cuisineOk = _cuisines.contains(_allLabel) || _cuisines.contains(r.category);
      return regionOk && cuisineOk;
    }).toList();
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
        },
        onRequestLocation: () {
          showLocationPermissionDialog(context, onGranted: () {
            setState(() => _sortBy = '가까운순');
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
    bool isBusyStatus(Restaurant r) => r.status == '자리없음' || r.status == '웨이팅많음';

    switch (widget.mode) {
      case RestaurantListMode.available:
        final openWithReport = filtered
            .where((r) => r.status != '영업안함' && !isBusyStatus(r) && r.hasCrowdUpdate)
            .toList();
        return _sortSection(openWithReport, provider);
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
      if (_sortBy == '여유로운순') {
        if (isClosed) {
          final am = BusinessHoursData(hoursCanonical: a.hours).minutesUntilNextOpen(now);
          final bm = BusinessHoursData(hoursCanonical: b.hours).minutesUntilNextOpen(now);
          if (am != bm) return am.compareTo(bm);
          return pop(b).compareTo(pop(a));
        }
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
      final ud = a.updated.compareTo(b.updated);
      if (ud != 0) return ud;
      return pop(b).compareTo(pop(a));
    });
    return sorted;
  }

  String get _title {
    switch (widget.mode) {
      case RestaurantListMode.available: return '바로 입장 가능해요';
      case RestaurantListMode.stamp: return '혼잡도를 알려주세요';
      case RestaurantListMode.busy: return '붐비고 있어요';
      case RestaurantListMode.closed: return '영업이 종료됐어요';
    }
  }

  Color get _dotColor {
    switch (widget.mode) {
      case RestaurantListMode.available: return const Color(0xFF4C9C2A);
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

  bool get _showCrowdInfo =>
      widget.mode == RestaurantListMode.available || widget.mode == RestaurantListMode.busy;

  bool get _showStampInfo => widget.mode == RestaurantListMode.stamp;

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
                    20, MediaQuery.of(context).padding.top + 12, 20,
                    _openDropdown != null ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뒤로가기 + 타이틀
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18, color: Color(0xFF111827)),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: _dotColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(_title,
                                style: TextStyle(
                                    fontFamily: 'OkDanDan',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: _titleColor)),
                          ],
                        ),
                        const Spacer(),
                        if (_showCrowdInfo)
                          CompositedTransformTarget(
                            link: _crowdInfoLink,
                            child: OverlayPortal(
                              controller: _crowdInfoOverlay,
                              overlayChildBuilder: (ctx) => CrowdLevelInfoPopup(
                                link: _crowdInfoLink,
                                onDismiss: _crowdInfoOverlay.hide,
                              ),
                              child: GestureDetector(
                                onTap: _crowdInfoOverlay.toggle,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14, color: Color(0xFF9CA3AF)),
                                    SizedBox(width: 4),
                                    Text('혼잡도 기준',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (_showStampInfo)
                          CompositedTransformTarget(
                            link: _stampInfoLink,
                            child: OverlayPortal(
                              controller: _stampInfoOverlay,
                              overlayChildBuilder: (ctx) => StampInfoPopup(
                                link: _stampInfoLink,
                                onDismiss: _stampInfoOverlay.hide,
                              ),
                              child: GestureDetector(
                                onTap: _stampInfoOverlay.toggle,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14, color: Color(0xFF9CA3AF)),
                                    SizedBox(width: 4),
                                    Text('스탬프 지급',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
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
                            onTap: () {
                              setState(() => _openDropdown = null);
                              _openFilterSheet(locationMode);
                            },
                          ),
                          const SizedBox(width: 8),
                          HomeFilterChip(
                            label: _sortBy,
                            active: _sortBy != '최신순',
                            open: _openDropdown == 'sort',
                            onTap: () => setState(() =>
                                _openDropdown =
                                    _openDropdown == 'sort' ? null : 'sort'),
                          ),
                          const SizedBox(width: 8),
                          HomeFilterChip(
                            label: _isAll(_regions) || _regions.isEmpty
                                ? '위치'
                                : _regions.length == 1
                                    ? _regions.first
                                    : '${_regions.first} 외 ${_regions.length - 1}',
                            active: !_isAll(_regions) && _regions.isNotEmpty,
                            open: _openDropdown == 'region',
                            onTap: () => setState(() => _openDropdown =
                                _openDropdown == 'region' ? null : 'region'),
                          ),
                          const SizedBox(width: 8),
                          HomeFilterChip(
                            label: _isAll(_cuisines) || _cuisines.isEmpty
                                ? '음식종류'
                                : _cuisines.length == 1
                                    ? _cuisines.first
                                    : '${_cuisines.first} 외 ${_cuisines.length - 1}',
                            active: !_isAll(_cuisines) && _cuisines.isNotEmpty,
                            open: _openDropdown == 'cuisine',
                            onTap: () => setState(() => _openDropdown =
                                _openDropdown == 'cuisine' ? null : 'cuisine'),
                          ),
                          const SizedBox(width: 8),
                          HomeCafeFilterChip(
                            active: _cuisines.length == 1 &&
                                _cuisines.contains('카페'),
                            onTap: () => setState(() {
                              _openDropdown = null;
                              if (_cuisines.length == 1 &&
                                  _cuisines.contains('카페')) {
                                _cuisines = {_allLabel};
                              } else {
                                _cuisines = {'카페'};
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 드롭다운 ──
              if (_openDropdown != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(10), blurRadius: 8)
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: _openDropdown == 'sort'
                        ? HomeDropdownGrid(
                            items: _sortOpts,
                            selected: {_sortBy},
                            onSelect: (v) {
                              if (v == '가까운순' && !locationMode) {
                                showLocationPermissionDialog(context,
                                    onGranted: () {
                                  setState(() => _sortBy = '가까운순');
                                });
                                return;
                              }
                              setState(() => _sortBy = v);
                            },
                            showReset: _sortBy != '최신순',
                            onReset: () => setState(() => _sortBy = '최신순'),
                          )
                        : _openDropdown == 'region'
                            ? HomeDropdownGrid(
                                items: _regionOpts,
                                selected: _regions,
                                multiSelect: true,
                                onSelect: (v) =>
                                    setState(() => _toggleFilter(_regions, v)),
                                showReset: !_isAll(_regions),
                                onReset: () => setState(() {
                                  _regions.clear();
                                  _regions.add(_allLabel);
                                }),
                              )
                            : HomeDropdownGrid(
                                items: _cuisineOpts,
                                selected: _cuisines,
                                multiSelect: true,
                                onSelect: (v) =>
                                    setState(() => _toggleFilter(_cuisines, v)),
                                showReset: !_isAll(_cuisines),
                                onReset: () => setState(() {
                                  _cuisines.clear();
                                  _cuisines.add(_allLabel);
                                }),
                              ),
                  ),
                ),

              // ── 콘텐츠 ──
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_openDropdown != null)
                      setState(() => _openDropdown = null);
                  },
                  child: RefreshIndicator(
                    color: const Color(0xFF5E8C4A),
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
                                      color: Color(0xFF9ECA8B))
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
