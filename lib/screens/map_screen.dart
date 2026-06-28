import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/map_pin_painter.dart';
import '../utils/navigation_helper.dart';
import '../navigation/app_route_observer.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/report_feedback.dart';
import '../widgets/report_sheet.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_kakao_map.dart';
import '../widgets/restaurant_image.dart';
import 'detail_screen.dart';
import 'location_permission_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with RouteAware {
  int _mapEpoch = 0;
  ModalRoute<void>? _route;
  Restaurant? _selected;
  bool _isLocated = false;
  bool _isRefreshing = false;
  static const _allLabel = '전체';
  String _reportFilter = _allLabel; // '전체' | '제보있음' | '제보없음'
  Set<String> _regions = {_allLabel};
  Set<String> _cuisines = {_allLabel};
  String? _openDropdown;
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();

  static const _regionOpts = [_allLabel, '정문', '중문', '후문'];
  static const _cuisineOpts = [
    _allLabel,
    '한식',
    '중식',
    '일식',
    '양식',
    '아시아',
    '분식',
    '카페',
  ];
  static const _reportOpts = [_allLabel, '제보있음', '제보없음'];
  static const _reportOptLabels = {_allLabel: '전체', '제보있음': '스탬프 1개', '제보없음': '스탬프 2개'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _remountMap() {
    if (!mounted) return;
    setState(() => _mapEpoch++);
  }

  @override
  void didPopNext() {
    _remountMap();
  }

  void _openDetail(Restaurant r) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)));
  }

  Future<void> _launchDirections(Restaurant r) async {
    await openInAppDirections(context, r);
  }

  bool _isAllFilter(Set<String> values) =>
      values.contains(_allLabel) && values.length == 1;

  String _filterChipLabel(Set<String> values, String fallback) {
    if (_isAllFilter(values) || values.isEmpty) return fallback;
    if (values.length == 1) return values.first;
    return '${values.first} 외 ${values.length - 1}';
  }

  void _toggleFilter(Set<String> target, String value) {
    if (value == _allLabel) {
      target
        ..clear()
        ..add(_allLabel);
      return;
    }
    target.remove(_allLabel);
    if (target.contains(value)) {
      target.remove(value);
    } else {
      target.add(value);
    }
    if (target.isEmpty) target.add(_allLabel);
  }

  List<Restaurant> _filter(List<Restaurant> all) {
    return all.where((r) {
      final q = _searchCtrl.text.trim().toLowerCase();
      final regionOk = _regions.contains(_allLabel) || _regions.contains(r.area);
      final cuisineOk =
          _cuisines.contains(_allLabel) || _cuisines.contains(r.category);
      final searchOk = q.isEmpty || '${r.name} ${r.area} ${r.category}'.toLowerCase().contains(q);
      final reportOk = switch (_reportFilter) {
        '제보있음' => r.status != '영업안함' && r.hasCrowdUpdate,
        '제보없음' => r.status != '영업안함' && !r.hasCrowdUpdate,
        _ => true,
      };
      return regionOk && cuisineOk && searchOk && reportOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppProvider>().restaurants;
    final filtered = _filter(all);
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final q = _searchCtrl.text.trim();

    return Stack(
      children: [
        // ── 지도 (풀스크린) ──
        Positioned.fill(
          child: RestaurantKakaoMap(
            key: ValueKey('kakao_map_$_mapEpoch'),
            restaurants: filtered,
            selected: _selected,
            onSelect: (r) => setState(() => _selected = _selected?.id == r.id ? null : r),
            onDeselect: () => setState(() => _selected = null),
            myLocationEnabled: _isLocated,
          ),
        ),

        // ── 플로팅 상단 UI ──
        Positioned(
          top: 0, left: 0, right: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, safeTop + 12, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 검색바 (pill)
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(color: Color(0x21000000), blurRadius: 18, offset: Offset(0, 0)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
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
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
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
                ),

                if (!_searchActive) ...[
                  const SizedBox(height: 8),
                  // 필터 칩 행
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MapFilterChip(
                          label: _filterChipLabel(_regions, '구역'),
                          active: !_isAllFilter(_regions),
                          open: _openDropdown == 'region',
                          onTap: () => setState(() =>
                              _openDropdown =
                                  _openDropdown == 'region' ? null : 'region'),
                        ),
                        const SizedBox(width: 8),
                        _MapFilterChip(
                          label: _filterChipLabel(_cuisines, '음식종류'),
                          active: !_isAllFilter(_cuisines),
                          open: _openDropdown == 'cuisine',
                          onTap: () => setState(() =>
                              _openDropdown =
                                  _openDropdown == 'cuisine' ? null : 'cuisine'),
                        ),
                        const SizedBox(width: 8),
                        _MapFilterChip(
                          label: _reportFilter == _allLabel
                              ? '스탬프'
                              : _reportOptLabels[_reportFilter]!,
                          active: _reportFilter != _allLabel,
                          open: _openDropdown == 'report',
                          onTap: () => setState(() =>
                              _openDropdown =
                                  _openDropdown == 'report' ? null : 'report'),
                          restingBg: const Color(0xFFF3F8F0),
                          restingText: const Color(0xFF4C9C2A),
                          leadingIcon: _reportFilter == _allLabel
                              ? Icons.stars_rounded
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // 드롭다운 패널
                  if (_openDropdown != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8, left: 4, right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 22,
                              offset: Offset(0, 0)),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      clipBehavior: Clip.antiAlias,
                      child: _openDropdown == 'region'
                          ? _DropdownGrid(
                              items: _regionOpts,
                              selected: _regions,
                              multiSelect: true,
                              onSelect: (v) => setState(() => _toggleFilter(_regions, v)),
                              onReset: () => setState(() {
                                _regions
                                  ..clear()
                                  ..add(_allLabel);
                              }),
                            )
                          : _openDropdown == 'cuisine'
                              ? _DropdownGrid(
                                  items: _cuisineOpts,
                                  selected: _cuisines,
                                  multiSelect: true,
                                  onSelect: (v) => setState(() => _toggleFilter(_cuisines, v)),
                                  onReset: () => setState(() {
                                    _cuisines
                                      ..clear()
                                      ..add(_allLabel);
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

                  // 범례 (필터 펼침 시 아래로 밀림)
                  if (!_searchActive) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _CrowdLegend(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),

        // ── 검색 결과 오버레이 ──
        if (_searchActive && q.isNotEmpty)
          Positioned(
            top: safeTop + 68,
            left: 0, right: 0, bottom: 0,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('검색 결과',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827))),
                        Text('${filtered.length}곳',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD1D5DB))),
                      ],
                    ),
                  ),
                  if (filtered.isEmpty)
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
                                  fontFamily: 'OkDanDan',
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
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => RestaurantCard(
                          restaurant: filtered[i],
                          onTap: () => _openDetail(filtered[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // ── 새로고침 / 내 위치 버튼 ──
        if (!_searchActive)
          Positioned(
            right: 16,
            bottom: _selected != null ? safeBottom + 264 : safeBottom + 112,
            child: GestureDetector(
              onTap: _isRefreshing
                  ? null
                  : () async {
                      setState(() => _isRefreshing = true);
                      await context.read<AppProvider>().refreshRestaurants();
                      if (mounted) setState(() => _isRefreshing = false);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isRefreshing ? const Color(0xFF9ECA8B) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x21000000), blurRadius: 18, offset: Offset(0, 0)),
                  ],
                ),
                child: Icon(
                  Icons.refresh,
                  size: 20,
                  color: _isRefreshing ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),

        // ── 내 위치 버튼 ──
        if (!_searchActive)
          Positioned(
            right: 16,
            bottom: _selected != null ? safeBottom + 200 : safeBottom + 48,
            child: GestureDetector(
              onTap: () {
                if (!context.read<AppProvider>().locationMode) {
                  showLocationPermissionDialog(context);
                  return;
                }
                setState(() => _isLocated = !_isLocated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isLocated ? const Color(0xFFF3F8F0) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x21000000), blurRadius: 18, offset: Offset(0, 0)),
                  ],
                ),
                child: Icon(
                  Icons.my_location,
                  size: 20,
                  color: _isLocated ? const Color(0xFF5E8C4A) : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),

        // ── 선택된 매장 카드 ──
        if (_selected != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _SelectedCard(
              restaurant: _selected!,
              onDetail: () => _openDetail(_selected!),
              onReport: _selected!.status == '영업안함' ? null : () => ReportSheet.show(
                context,
                _selected!,
                (status) => submitCrowdReportFeedback(
                  context,
                  _selected!.id,
                  status,
                ),
              ),
              onDismiss: () => setState(() => _selected = null),
              onDirections: () => _launchDirections(_selected!),
              safeBottom: safeBottom,
            ),
          ),
      ],
    );
  }
}

// ── 혼잡도 범례 ──
class _CrowdLegend extends StatelessWidget {
  const _CrowdLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 0)),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(color: Color(0xFF4C9C2A), label: '여유로움'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFFBBF24), label: '약간혼잡'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFF97316), label: '자리없음'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFDC2626), label: '웨이팅'),
        ],
      ),
    );
  }
}

// ── 범례 아이템 ──
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
      ],
    );
  }
}

// ── 가짜 지도 ──
class _FakeMap extends StatelessWidget {
  final List<Restaurant> restaurants;
  final Restaurant? selected;
  final ValueChanged<Restaurant> onSelect;
  final VoidCallback? onDeselect;

  const _FakeMap({
    required this.restaurants,
    required this.selected,
    required this.onSelect,
    this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        GestureDetector(
          onTap: onDeselect,
          child: Container(
            color: const Color(0xFFEDE8DF),
            child: CustomPaint(
              painter: _MapPainter(),
              size: Size(size.width, size.height),
            ),
          ),
        ),
        ...restaurants.map((r) {
          final left = r.x / 100 * size.width;
          final top = r.y / 100 * size.height;
          final meta = crowdStatusMeta(
            r.status != '영업안함' && !r.hasCrowdUpdate ? '제보필요' : r.status,
          );
          final isSelected = selected?.id == r.id;
          final pinSize = isSelected ? 40.0 : 28.0;
          return Positioned(
            left: left - pinSize / 2,
            top: top - pinSize / 2,
            child: GestureDetector(
              onTap: () => onSelect(r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: pinSize,
                    height: pinSize * MapPinPainter.aspectRatio,
                    child: CustomPaint(
                      painter: MapPinPainter(
                        fillColor: Color(meta.color),
                        borderWidth: isSelected ? 3.0 : 2.0,
                        shadowAlpha: isSelected ? 40 : 20,
                        shadowBlur: isSelected ? 12.0 : 6.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 0))
                      ],
                    ),
                    child: Text(
                      r.name,
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFD4CCBB)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height * 0.55),
        Offset(size.width, size.height * 0.55), roadPaint);
    canvas.drawLine(Offset(size.width * 0.55, 0),
        Offset(size.width * 0.55, size.height), roadPaint);
    roadPaint.strokeWidth = 4;
    canvas.drawLine(Offset(size.width * 0.3, 0),
        Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.35), roadPaint);

    final blockPaint = Paint()..color = const Color(0xFFCCC5B5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.04, size.height * 0.08,
                size.width * 0.22, size.height * 0.22),
            const Radius.circular(6)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.6, size.height * 0.08,
                size.width * 0.35, size.height * 0.22),
            const Radius.circular(6)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.04, size.height * 0.6,
                size.width * 0.2, size.height * 0.3),
            const Radius.circular(6)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.62, size.height * 0.6,
                size.width * 0.32, size.height * 0.25),
            const Radius.circular(6)),
        blockPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 플로팅 필터 칩 (그림자만, 테두리 없음) ──
class _MapFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool open;
  final VoidCallback onTap;
  /// 미선택 상태 배경/글자색을 기본값과 다르게 쓰고 싶을 때만 지정
  final Color? restingBg;
  final Color? restingText;
  /// 라벨 앞에 표시할 아이콘 (선택)
  final IconData? leadingIcon;

  const _MapFilterChip({
    required this.label,
    required this.active,
    required this.open,
    required this.onTap,
    this.restingBg,
    this.restingText,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final on = active || open;
    final restBg = restingBg ?? Colors.white;
    final restText = restingText ?? const Color(0xFF374151);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF9ECA8B) : restBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x21000000), blurRadius: 18, offset: Offset(0, 0)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 14,
                color: on ? const Color(0xFF111827) : restText,
              ),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: on ? const Color(0xFF111827) : restText)),
            const SizedBox(width: 4),
            Icon(
              open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 12,
              color: on ? const Color(0xFF111827) : restText,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 드롭다운 그리드 ──
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

// ── 선택된 매장 카드 (바텀시트 스타일) ──
class _SelectedCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onDetail;
  final VoidCallback? onReport;
  final VoidCallback onDismiss;
  final VoidCallback onDirections;
  final double safeBottom;

  const _SelectedCard({
    required this.restaurant,
    required this.onDetail,
    required this.onReport,
    required this.onDismiss,
    required this.onDirections,
    required this.safeBottom,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final noReport = r.status != '영업안함' && !r.hasCrowdUpdate;
    final displayStatus = noReport ? '제보필요' : r.status;
    final meta = crowdStatusMeta(displayStatus);
    final statusColor = Color(meta.color);

    return GestureDetector(
      onTap: onDetail,
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 28, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40, height: 6,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3)),
            ),
          ),

          // 매장 정보 행
          GestureDetector(
            onTap: onDetail,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: RestaurantImage(
                      url: r.imageUrl,
                      fallback: () => Center(
                        child: Text(
                          r.name.isNotEmpty ? r.name[0] : '?',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF5E8C4A)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827))),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text('${r.area} · ',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF9CA3AF))),
                          Text(meta.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: statusColor)),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
                ],
              ),
            ),
          ),

          // 버튼 영역
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, safeBottom + 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDirections,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF5E8C4A), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation_outlined,
                                size: 16, color: Color(0xFF5E8C4A)),
                            SizedBox(width: 6),
                            Text('길찾기',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF5E8C4A))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Opacity(
                    opacity: onReport == null ? 0.4 : 1.0,
                    child: GestureDetector(
                      onTap: onReport,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF9ECA8B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(noReport ? '스탬프 2개 받기' : '혼잡도 제보하기',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827))),
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
      ),
    );
  }
}
