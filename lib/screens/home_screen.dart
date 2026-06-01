import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/nearby_prompt.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/report_sheet.dart';
import 'detail_screen.dart';
import 'location_permission_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _sortBy = '인기순';
  Set<String> _regions = {};
  Set<String> _cuisines = {};
  String? _openDropdown; // 'sort' | 'region' | 'cuisine' | null
  bool _searchActive = false;
  bool _showBookmarked = false;
  bool _showNearby = false;
  bool? _prevLocationMode;
  final _searchCtrl = TextEditingController();

  static const _regionOpts = ['학식', '정문', '중문', '후문'];
  static const _cuisineOpts = ['학식', '한식', '중식', '일식', '양식', '아시아', '분식', '카페'];
  static const _sortOpts = ['인기순', '가까운순', '여유로운순'];

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
    var list = all.where((r) {
      final regionOk = _regions.isEmpty || _regions.contains(r.area);
      final cuisineOk = _cuisines.isEmpty || _cuisines.contains(r.category);
      final bookmarkOk = !_showBookmarked || bookmarks.contains(r.id);
      return regionOk && cuisineOk && bookmarkOk;
    }).toList();
    list.sort((a, b) {
      if (_sortBy == '가까운순') return a.distance.compareTo(b.distance);
      if (_sortBy == '여유로운순') {
        const pri = {'여유로움': 0, '약간혼잡': 1, '자리없음': 2, '영업안함': 3};
        final d = (pri[a.status] ?? 9) - (pri[b.status] ?? 9);
        return d != 0 ? d : b.totalReports.compareTo(a.totalReports);
      }
      return b.totalReports.compareTo(a.totalReports);
    });
    return list;
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

  void _openReport(Restaurant r) => ReportSheet.show(context, r, (status) {
    context.read<AppProvider>().reportStatus(r.id, status);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
        '제보가 반영됐어요. 감사해요!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF111827),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(milliseconds: 1600),
      elevation: 0,
    ));
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final locationMode = provider.locationMode;
    final all = provider.restaurants;
    final filtered = _filter(all, provider.bookmarks);
    final searchResults = _search(all, _searchCtrl.text);

    final available = filtered.where((r) => r.status == '여유로움' || r.status == '약간혼잡').toList();
    final busy = filtered.where((r) => r.status == '자리없음').toList();
    final recommended = available.isNotEmpty
        ? available.reduce((a, b) => a.totalReports >= b.totalReports ? a : b)
        : null;
    final availableCards = available.where((r) => r.id != recommended?.id).toList();

    return Stack(
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
                        color: const Color(0xFFFF6207),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Center(
                          child: Icon(Icons.restaurant_menu, color: Colors.white, size: 20)),
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
                              active: _sortBy != '인기순',
                              open: _openDropdown == 'sort',
                              onTap: () => setState(() =>
                                  _openDropdown = _openDropdown == 'sort' ? null : 'sort'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: _regions.isEmpty
                                  ? '구역'
                                  : _regions.length == 1
                                      ? _regions.first
                                      : '${_regions.first} 외 ${_regions.length - 1}',
                              active: _regions.isNotEmpty,
                              open: _openDropdown == 'region',
                              onTap: () => setState(() =>
                                  _openDropdown = _openDropdown == 'region' ? null : 'region'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: _cuisines.isEmpty
                                  ? '음식종류'
                                  : _cuisines.length == 1
                                      ? _cuisines.first
                                      : '${_cuisines.first} 외 ${_cuisines.length - 1}',
                              active: _cuisines.isNotEmpty,
                              open: _openDropdown == 'cuisine',
                              onTap: () => setState(() =>
                                  _openDropdown = _openDropdown == 'cuisine' ? null : 'cuisine'),
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
                              ? const Color(0xFFFF6207)
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
                              ? Colors.white
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
                          onSelect: (v) => setState(() {
                            _regions.contains(v) ? _regions.remove(v) : _regions.add(v);
                          }),
                          onReset: () => setState(() => _regions.clear()),
                        )
                      : _DropdownGrid(
                          items: _cuisineOpts,
                          selected: _cuisines,
                          multiSelect: true,
                          onSelect: (v) => setState(() {
                            _cuisines.contains(v) ? _cuisines.remove(v) : _cuisines.add(v);
                          }),
                          onReset: () => setState(() => _cuisines.clear()),
                        ),
            ),
          ),

        // ── 콘텐츠 ──
        Expanded(
          child: _searchActive
              ? _buildSearch(searchResults)
              : _buildList(recommended, availableCards, busy),
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
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
          )
        else
          Expanded(
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
      ],
    );
  }

  Widget _buildList(Restaurant? recommended, List<Restaurant> available, List<Restaurant> busy) {
    return GestureDetector(
      onTap: () { if (_openDropdown != null) setState(() => _openDropdown = null); },
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
                        color: Color(0xFF22C55E), shape: BoxShape.circle),
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
                  onDetail: () => _openDetail(recommended),
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
      {required this.label, required this.active, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final on = active || open;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFFF6207) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? const Color(0xFFFF6207) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: on ? Colors.white : const Color(0xFF374151)),
            ),
            const SizedBox(width: 4),
            Icon(
              open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 12,
              color: on ? Colors.white : const Color(0xFF374151),
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

  const _DropdownGrid({
    required this.items,
    required this.selected,
    this.multiSelect = false,
    required this.onSelect,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (multiSelect && selected.isNotEmpty)
          GestureDetector(
            onTap: onReset,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('초기화',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF6207))),
            ),
          ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: items.length <= 3 ? items.length : 4,
          childAspectRatio: items.length <= 3 ? 2.8 : 2.2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          children: items.map((opt) {
            final on = selected.contains(opt);
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFFFF3EC) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: on ? const Color(0xFFFF6207) : const Color(0xFF374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (on)
                      const Icon(Icons.check, size: 14, color: Color(0xFFFF6207)),
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
