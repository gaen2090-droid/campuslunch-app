import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/nearby_prompt.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_image.dart';
import '../widgets/rice_ball_icon.dart';
import '../utils/available_restaurant_ranking.dart';
import '../utils/business_hours.dart';
import '../utils/report_feedback.dart';
import '../widgets/report_sheet.dart';
import 'detail_screen.dart';
import 'location_permission_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _allLabel = '전체';
  String _sortBy = '최신순';
  Set<String> _regions = {_allLabel};
  Set<String> _cuisines = {_allLabel};
  String _reportFilter = _allLabel; // '전체' | '제보있음' | '제보없음'
  String? _openDropdown; // 'sort' | 'region' | 'cuisine' | 'report' | null
  bool _searchActive = false;
  bool _showBookmarked = false;
  bool _showNearby = false;
  bool? _prevLocationMode;
  String? _lastBannerImpressionId;
  final _searchCtrl = TextEditingController();

  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [_allLabel, '한식', '중식', '일식', '양식', '아시아', '분식', '카페'];
  static const _sortOpts = ['최신순', '인기순', '가까운순', '여유로운순'];
  static const _reportOpts = [_allLabel, '제보있음', '제보없음'];
  static const _reportOptLabels = {_allLabel: '전체', '제보있음': '스탬프 1개', '제보없음': '스탬프 2개'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationMode = context.read<AppProvider>().locationMode;
    if (locationMode && _prevLocationMode != true) {
      _showNearby = true;
    }
    _prevLocationMode = locationMode;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Restaurant> _filter(List<Restaurant> all, Set<String> bookmarks) {
    return all.where((r) {
      final regionOk = _regions.contains(_allLabel) || _regions.contains(r.area);
      final cuisineOk = _cuisines.contains(_allLabel) || _cuisines.contains(r.category);
      final bookmarkOk = !_showBookmarked || bookmarks.contains(r.id);
      return regionOk && cuisineOk && bookmarkOk;
    }).toList();
  }

  // 섹션별 독립 정렬
  List<Restaurant> _sortSection(List<Restaurant> list, {bool isClosed = false, bool isBusy = false}) {
    final useAlgo = context.read<AppProvider>().useAlgorithmRanking;
    int pop(Restaurant r) => useAlgo
        ? (r.popularityScore > 0 ? r.popularityScore : r.totalReports)
        : (r.manualRank > 0 ? -r.manualRank : -9999);

    final sorted = List<Restaurant>.from(list);
    sorted.sort((a, b) {
      final now = DateTime.now();

      if (_sortBy == '인기순') {
        if (isClosed) return pop(b).compareTo(pop(a));
        if (isBusy) {
          final pd = pop(b).compareTo(pop(a));
          if (pd != 0) return pd;
          return a.updated.compareTo(b.updated);
        }
        // 바로입장가능: 30분 이내 우선 → 인기순 → 최신순
        final aG = a.updated <= 30 ? 0 : 1;
        final bG = b.updated <= 30 ? 0 : 1;
        if (aG != bG) return aG.compareTo(bG);
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
        if (isBusy) {
          final ud = a.updated.compareTo(b.updated);
          if (ud != 0) return ud;
          return pop(b).compareTo(pop(a));
        }
        // 바로입장가능: 여유로움→약간혼잡 → 최신순 → 인기순
        const pri = {'여유로움': 0, '약간혼잡': 1};
        final sd = (pri[a.status] ?? 9) - (pri[b.status] ?? 9);
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

      if (isBusy) {
        final aG = a.updated <= 60 ? 0 : 1;
        final bG = b.updated <= 60 ? 0 : 1;
        if (aG != bG) return aG.compareTo(bG);
        final pd = pop(b).compareTo(pop(a));
        if (pd != 0) return pd;
        return a.updated.compareTo(b.updated);
      }

      // 바로입장가능 최신순
      int availGroup(Restaurant r) {
        final isRelaxed = r.status == '여유로움';
        final u = r.updated;
        if (isRelaxed && u <= 15) return 0;
        if (isRelaxed && u <= 30) return 1;
        if (!isRelaxed && u <= 15) return 2;
        if (!isRelaxed && u <= 30) return 3;
        if (isRelaxed) return 4;
        return 5;
      }
      final ag = availGroup(a), bg = availGroup(b);
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
    final filtered = _filter(all, provider.bookmarks);
    final searchResults = _search(all, _searchCtrl.text);

    // 제보 있는 영업 중 매장과 제보 없는 매장 분리
    final openWithReport = filtered.where((r) =>
        r.status != '영업안함' && r.status != '자리없음' && r.hasCrowdUpdate).toList();
    final needsReport = filtered.where((r) =>
        r.status != '영업안함' && r.status != '자리없음' && !r.hasCrowdUpdate).toList();

    final availableSorted = _sortSection(openWithReport);
    // 추천 배너는 항상 최신순 기준 알고리즘으로 고정
    final recommended = buildAvailableSection(filtered, provider.useAlgorithmRanking).recommended;
    final availableCards = recommended == null
        ? availableSorted
        : availableSorted.where((r) => r.id != recommended.id).toList();
    final busy = _sortSection(
      filtered.where((r) => r.status == '자리없음').toList(),
      isBusy: true,
    );
    // 영업안함은 필터 무관하게 항상 전체 표시
    final closedAll = all.where((r) => r.status == '영업안함').toList();
    final closed = _sortSection(
      closedAll,
      isClosed: true,
    );

    // 제보여부 필터: 제보있음 → 제보필요/영업종료 매장 숨김, 제보없음 → 제보필요 매장만 표시
    final showNeedsReport = _reportFilter != '제보있음';
    final showClosed = _reportFilter == _allLabel;
    final availableCardsFiltered = _reportFilter == '제보없음' ? <Restaurant>[] : availableCards;
    final recommendedFiltered = _reportFilter == '제보없음' ? null : recommended;
    final busyFiltered = _reportFilter == '제보없음' ? <Restaurant>[] : busy;
    final needsReportFiltered = showNeedsReport ? needsReport : <Restaurant>[];
    final closedFiltered = showClosed ? closed : <Restaurant>[];

    _trackBannerImpression(recommendedFiltered);

    return Stack(
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
                                hintText: '매장명, 구역, 음식종류 검색',
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
                  ],
                ],
              ),

              if (!_searchActive) ...[
                const SizedBox(height: 10),
                // 필터 칩
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                                  _openDropdown = _openDropdown == 'region' ? null : 'region'),
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
                                  _openDropdown = _openDropdown == 'cuisine' ? null : 'cuisine'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: _reportFilter == _allLabel
                                  ? '스탬프 받기'
                                  : _reportOptLabels[_reportFilter]!,
                              active: _reportFilter != _allLabel,
                              open: _openDropdown == 'report',
                              onTap: () => setState(() =>
                                  _openDropdown = _openDropdown == 'report' ? null : 'report'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showBookmarked = !_showBookmarked),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _showBookmarked
                              ? const Color(0xFF9ECA8B)
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: _showBookmarked
                              ? null
                              : Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Icon(
                          _showBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          size: 16,
                          color: _showBookmarked
                              ? const Color(0xFF111827)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── 드롭다운 ──
        if (_openDropdown != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8)],
              ),
              padding: const EdgeInsets.all(12),
              child: _openDropdown == 'sort'
                  ? _DropdownGrid(
                      items: _sortOpts,
                      selected: {_sortBy},
                      onSelect: (v) {
                        if (v == '가까운순' && !locationMode) {
                          showLocationPermissionDialog(context, onGranted: () {
                            setState(() { _sortBy = '가까운순'; _openDropdown = null; });
                          });
                          return;
                        }
                        setState(() { _sortBy = v; _openDropdown = null; });
                      },
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
                      : _openDropdown == 'cuisine'
                          ? _DropdownGrid(
                              items: _cuisineOpts,
                              selected: _cuisines,
                              multiSelect: true,
                              onSelect: (v) => setState(() => _toggleFilter(_cuisines, v)),
                              onReset: () => setState(() {
                                _cuisines.clear();
                                _cuisines.add(_allLabel);
                              }),
                            )
                          : _DropdownGrid(
                              items: _reportOpts,
                              labelFor: (v) => _reportOptLabels[v]!,
                              selected: {_reportFilter},
                              onSelect: (v) => setState(() {
                                _reportFilter = v;
                                _openDropdown = null;
                              }),
                            ),
            ),
          ),

        // ── 콘텐츠 ──
        Expanded(
          child: _searchActive
              ? _buildSearch(searchResults)
              : _buildList(recommendedFiltered, availableCardsFiltered, needsReportFiltered, busyFiltered, closedFiltered),
        ),
          ],
        ),

        // ── 근처 매장 제보 요청 팝업 ──
        if (_showNearby && !_searchActive)
          Positioned(
            left: 0, right: 0, bottom: 80,
            child: NearbyPrompt(
              restaurants: all,
              onClose: () => setState(() => _showNearby = false),
              onReport: (r) {
                setState(() => _showNearby = false);
                _openReport(r);
              },
            ),
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
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Text('검색 결과가 없어요.',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFD1D5DB),
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

  Widget _buildList(Restaurant? recommended, List<Restaurant> available, List<Restaurant> needsReport, List<Restaurant> busy, List<Restaurant> closed) {
    return GestureDetector(
      onTap: () { if (_openDropdown != null) setState(() => _openDropdown = null); },
      child: RefreshIndicator(
        color: const Color(0xFF5E8C4A),
        onRefresh: () => context.read<AppProvider>().refreshRestaurants(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
        children: [
          // 바로 입장 가능
          if (recommended != null || available.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF4C9C2A), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('바로 입장 가능',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827))),
                ],
              ),
            ),
            if (recommended != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: HeroRestaurantCard(
                  restaurant: recommended,
                  onDetail: () => _openRecommendedDetail(recommended),
                  onReport: () => _openReport(recommended),
                ),
              ),
            ...available.map((r) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: RestaurantCard(restaurant: r, onTap: () => _openDetail(r)),
                )),
          ],

          // 붐비는 매장
          if (busy.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, (recommended != null || available.isNotEmpty) ? 8 : 12, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFFEF4444), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('붐비는 매장',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827))),
                ],
              ),
            ),
            ...busy.map((r) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: RestaurantCard(restaurant: r, onTap: () => _openDetail(r)),
                )),
          ],

          // 제보가 필요해요
          if (needsReport.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, (recommended != null || available.isNotEmpty || busy.isNotEmpty) ? 8 : 12, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF111827), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('혼잡도를 알려주세요',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827))),
                ],
              ),
            ),
            ...needsReport.map((r) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _NeedsReportCard(restaurant: r, onTap: () => _openDetail(r)),
                )),
          ],

          // 영업종료
          if (closed.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, (recommended != null || available.isNotEmpty || busy.isNotEmpty || needsReport.isNotEmpty) ? 8 : 12, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF9CA3AF), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('영업종료',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            ...closed.map((r) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: RestaurantCard(restaurant: r, onTap: () => _openDetail(r)),
                )),
          ],

          if (recommended == null &&
              available.isEmpty &&
              busy.isEmpty &&
              needsReport.isEmpty &&
              closed.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 48, 20, 0),
              child: Center(
                child: Text(
                  '표시할 매장이 없어요.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _NeedsReportCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;
  const _NeedsReportCard({required this.restaurant, required this.onTap});

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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool open;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.active, required this.open, required this.onTap});

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (multiSelect && selected.isNotEmpty && !_isAllSelected(selected))
          GestureDetector(
            onTap: onReset,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('초기화',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5E8C4A))),
            ),
          ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: forceFourColumns ? 4 : (items.length <= 3 ? items.length : 4),
          childAspectRatio: forceFourColumns ? 2.2 : (items.length <= 3 ? 2.8 : 2.2),
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          children: items.map((opt) {
            final on = selected.contains(opt);
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFF3F8F0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        labelFor != null ? labelFor!(opt) : opt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: on ? const Color(0xFF5E8C4A) : const Color(0xFF374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (on)
                      const Icon(Icons.check, size: 14, color: Color(0xFF5E8C4A)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
