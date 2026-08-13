import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/map_pin_painter.dart';
import '../utils/map_camera_fit.dart';
import '../utils/navigation_helper.dart';
import '../navigation/app_route_observer.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/report_feedback.dart';
import '../widgets/report_sheet.dart';
import '../widgets/restaurant_kakao_map.dart';
import '../widgets/restaurant_image.dart';
import 'detail_screen.dart';
import 'home_screen.dart' show SimpleFilterSheet;
import 'location_permission_screen.dart';
import 'map_search_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with RouteAware {
  ModalRoute<void>? _route;
  Restaurant? _selected;
  bool _isLocated = false;
  bool _isRefreshing = false;
  int _cameraFitToken = 0;
  RestaurantKakaoMapState? _mapState;
  bool _showSearchOverlay = false;
  static const _allLabel = '전체';
  String _reportFilter = _allLabel; // '전체' | '제보있음' | '제보없음'
  Set<String> _regions = {_allLabel};
  Set<String> _cuisines = {_allLabel};
  bool _bookmarkOnly = false;
  bool _mapFilterLoaded = false;

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
    if (!_mapFilterLoaded) {
      _mapFilterLoaded = true;
      final p = context.read<AppProvider>();
      _regions = Set.from(p.mapFilterRegions);
      _cuisines = Set.from(p.mapFilterCuisines);
      _bookmarkOnly = p.mapFilterBookmarkOnly;
      _reportFilter = p.mapFilterReport;
    }
  }

  void _saveMapFilter() {
    context.read<AppProvider>().setMapFilter(
      regions: Set.from(_regions),
      cuisines: Set.from(_cuisines),
      bookmarkOnly: _bookmarkOnly,
      report: _reportFilter,
    );
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 검색은 이제 별도 라우트가 아니라 지도 위 오버레이라 didPopNext를 타지
    // 않는다 — 여기서 remount하던 대상은 실제로는 필터 바텀시트(음식종류 등)나
    // 상세화면에서 돌아올 때다. 매번 지도를 통째로 remount하면, 리마운트가
    // 끝나기 전(_mapLayerReady == false)에 다른 필터를 연달아 조작할 경우
    // didUpdateWidget의 카메라 재조정이 씹혀 "정문/후문 선택 후 음식종류
    // 선택하면 반영 안 됨" 버그가 생긴다. remount 없이 마커만 다시 그린다
    // (당시 remount로 되돌렸던 리사이즈 저더는 MainScreen/MapScreen의
    // resizeToAvoidBottomInset 수정으로 별도 해결됨).
    _mapState?.refreshAfterReturn();
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

  void _bumpCameraFit() {
    _cameraFitToken++;
  }

  void _openSimpleSheet({
    required String title,
    required List<String> items,
    required Set<String> selected,
    required void Function(Set<String>) onApply,
    required VoidCallback onReset,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SimpleFilterSheet(
        title: title,
        items: items,
        selected: selected,
        multiSelect: true,
        isActive: false,
        locationMode: context.read<AppProvider>().locationMode,
        onApply: onApply,
        onReset: onReset,
        onRequestLocation: () {},
      ),
    );
  }

  void _openStampCriteriaSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StampCriteriaSheet(),
    );
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

  bool _isSingleRegion() => _regions.length == 1 && !_regions.contains(_allLabel);

  List<Restaurant> _filter(List<Restaurant> all, Set<String> bookmarks) {
    return all.where((r) {
      final regionOk = _regions.contains(_allLabel) || _regions.contains(r.area);
      final cuisineOk =
          _cuisines.contains(_allLabel) || _cuisines.contains(r.category);
      final reportOk = switch (_reportFilter) {
        '제보있음' => r.status != '영업안함' && r.hasCrowdUpdate,
        '제보없음' => r.status != '영업안함' && !r.hasCrowdUpdate,
        _ => true,
      };
      final bookmarkOk = !_bookmarkOnly || bookmarks.contains(r.id);
      return regionOk && cuisineOk && reportOk && bookmarkOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final all = provider.restaurants;
    final filtered = _filter(all, provider.bookmarks);
    final jeongmunRestaurants = all.where((r) => r.area == '정문').toList();
    final hasNeedsReportRestaurant =
        all.any((r) => r.status != '영업안함' && !r.hasCrowdUpdate);
    if (!hasNeedsReportRestaurant && _reportFilter == '제보없음') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _reportFilter = _allLabel);
        _saveMapFilter();
      });
    }
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // 검색 오버레이의 TextField가 포커스를 얻거나 잃을 때(오버레이 열림/취소,
    // 매장 선택으로 오버레이가 닫힘) 키보드가 나타났다 사라지면서 이 화면의
    // body 크기가 바뀌면, 그 위에 Positioned.fill로 깔린 네이티브 카카오맵
    // PlatformView(virtual display)까지 리사이즈되어 지도가 늘었다 줄었다
    // 하는 버벅임이 생긴다(로그로 확인: displayId=254 handleResized
    // 2201→2021). 지도 탭 전용 Scaffold로 body 크기를 키보드와 무관하게
    // 고정해 막는다 — MainScreen의 공유 Scaffold를 바꾸면 다른 탭(홈 검색창
    // 등)의 키보드 회피까지 깨지므로 여기서만 적용한다.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
      children: [
        // ── 지도 (풀스크린) ──
        Positioned.fill(
          child: RestaurantKakaoMap(
            restaurants: filtered,
            selected: _selected,
            onSelect: (r) {
              final wasSelected = _selected?.id == r.id;
              setState(() => _selected = wasSelected ? null : r);
              if (!wasSelected) {
                context.read<AppProvider>().recordMapMarkerClick(r.id);
              }
            },
            onDeselect: () => setState(() => _selected = null),
            showMyLocationMarker: provider.locationMode,
            myLocationEnabled: provider.locationMode,
            cameraFitToken: _cameraFitToken,
            cameraFitProfile: _isSingleRegion()
                ? CameraFitProfile.tight
                : CameraFitProfile.balanced,
            initialFocusRestaurants: jeongmunRestaurants,
            onMapReady: (map) => _mapState = map,
          ),
        ),

        // ── 플로팅 상단 UI ──
        Positioned(
          top: 0, left: 0, right: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, safeTop + 12, 0, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 검색바 (pill) — 탭하면 검색 오버레이 표시 (별도 라우트 push 아님:
                // push하면 뒤로 돌아올 때 didPopNext가 걸려 네이티브 지도 뷰가
                // 파괴·재생성되면서 검은 화면/버벅임이 생긴다)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => setState(() => _showSearchOverlay = true),
                    child: Container(
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
                          const Text(
                            '매장명, 위치, 음식종류 검색',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (true) ...[
                  const SizedBox(height: 12),
                  // 필터 칩 행 — 좌우 여백(20) 밖으로도 스크롤되도록 전체 폭으로
                  // 넓히고, 시작/끝 위치만 padding으로 맞춘다.
                  // clipBehavior: none — 기본값(hardEdge)은 스크롤 뷰포트 위아래를
                  // 딱 잘라내는데, 그 경계가 각 칩의 둥근 그림자(blurRadius 18)를
                  // 수평으로 잘라 사각형 띠처럼 보이게 만든다. 검색바(스크롤뷰 밖)는
                  // 이 클리핑이 없어 정상적으로 둥글게 퍼져 보였던 것과 대조됨.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _MapFilterChip(
                          label: '카페',
                          active: _cuisines.length == 1 && _cuisines.contains('카페'),
                          open: false,
                          showArrow: false,
                          trailingIcon: (_cuisines.length == 1 && _cuisines.contains('카페'))
                              ? Icons.local_cafe_rounded
                              : Icons.local_cafe_outlined,
                          onTap: () {
                            final isActive =
                                _cuisines.length == 1 && _cuisines.contains('카페');
                            setState(() {
                              _cuisines = isActive ? {_allLabel} : {'카페'};
                            });
                            _saveMapFilter();
                          },
                        ),
                        const SizedBox(width: 8),
                        _MapFilterChip(
                          label: '즐겨찾기',
                          active: _bookmarkOnly,
                          open: false,
                          showArrow: false,
                          trailingIcon: _bookmarkOnly
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          onTap: () {
                            setState(() => _bookmarkOnly = !_bookmarkOnly);
                            _saveMapFilter();
                          },
                        ),
                        if (!_isAllFilter(_cuisines) ||
                            !_isAllFilter(_regions) ||
                            _bookmarkOnly) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _cuisines = {_allLabel};
                                _regions = {_allLabel};
                                _bookmarkOnly = false;
                              });
                              _saveMapFilter();
                              _bumpCameraFit();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.all(Radius.circular(20)),
                                boxShadow: [
                                  BoxShadow(color: Color(0x21000000), blurRadius: 18, offset: Offset(0, 0)),
                                ],
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
                        ],
                        const SizedBox(width: 8),
                        ...['정문', '중문', '후문'].map((area) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _MapFilterChip(
                            label: area,
                            active: _regions.length == 1 && _regions.contains(area),
                            open: false,
                            showArrow: false,
                            onTap: () {
                              final isActive = _regions.length == 1 && _regions.contains(area);
                              setState(() {
                                if (isActive) {
                                  _regions = {_allLabel};
                                } else {
                                  _regions = {area};
                                }
                                _bumpCameraFit();
                              });
                              _saveMapFilter();
                            },
                          ),
                        )),
                        _MapFilterChip(
                          label: _filterChipLabel(_cuisines, '음식종류'),
                          active: !_isAllFilter(_cuisines),
                          open: false,
                          onTap: () => _openSimpleSheet(
                            title: '음식종류',
                            items: _cuisineOpts,
                            selected: Set.from(_cuisines),
                            onApply: (v) {
                              setState(() => _cuisines = v);
                              _saveMapFilter();
                            },
                            onReset: () {
                              setState(() { _cuisines = {_allLabel}; });
                              _saveMapFilter();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),


                  // 범례
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StampCriteriaBadge(onTap: _openStampCriteriaSheet),
                        const SizedBox(height: 8),
                        const _CrowdLegend(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (provider.restaurantsLoadFailed && !provider.restaurantsLoading)
          Positioned(
            top: safeTop + 64,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x21000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 18, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '매장 정보를 불러오지 못했어요',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => provider.refreshRestaurants(),
                      child: const Text(
                        '다시 시도',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── 새로고침 / 내 위치 버튼 ──
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
                  color: _isRefreshing ? AppColors.primaryCta : Colors.white,
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
        Positioned(
            right: 16,
            bottom: _selected != null ? safeBottom + 200 : safeBottom + 48,
            child: GestureDetector(
              onTap: () {
                if (!context.read<AppProvider>().locationMode) {
                  showLocationPermissionDialog(context);
                  return;
                }
                setState(() => _isLocated = true);
                _mapState?.moveToMyLocation();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isLocated ? const Color(0xFFF3F4F6) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x21000000), blurRadius: 18, offset: Offset(0, 0)),
                  ],
                ),
                child: Icon(
                  Icons.my_location,
                  size: 20,
                  color: _isLocated ? AppColors.primaryCta : const Color(0xFF9CA3AF),
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

        // ── 검색 오버레이 ──
        if (_showSearchOverlay)
          Positioned.fill(
            child: MapSearchScreen(
              onClose: () => setState(() => _showSearchOverlay = false),
              onSelectRestaurant: (r) {
                setState(() {
                  _showSearchOverlay = false;
                  _selected = r;
                });
              },
            ),
          ),
      ],
      ),
    );
  }
}

// ── 스탬프 지급 기준 배지 ──
class _StampCriteriaBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _StampCriteriaBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 0)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(painter: StarPinPainter()),
            ),
            const SizedBox(width: 4),
            const Text('스탬프 지급 기준',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 12, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _StampCriteriaSheet extends StatelessWidget {
  const _StampCriteriaSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20, 24, 20, MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '스탬프 지급 기준',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 16),
            const _StampCriteriaLine('혼잡도를 제보하면 스탬프를 1개 받아요.'),
            const _StampCriteriaMarkerLine(),
            const _StampCriteriaLine('단, 하루 최대 3개의 스탬프를 획득할 수 있어요.'),
            const _StampCriteriaLine('획득한 스탬프는 마이페이지에서 확인할 수 있어요.'),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryCta,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    '확인했어요',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
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

class _StampCriteriaLine extends StatelessWidget {
  final String text;
  const _StampCriteriaLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· ', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// "스탬프 마커" 텍스트 대신 실제 별 마커 아이콘을 문장 안에 인라인으로 넣는 안내 줄.
class _StampCriteriaMarkerLine extends StatelessWidget {
  const _StampCriteriaMarkerLine();

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· ', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CustomPaint(painter: StarPinPainter()),
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: ' 마커는 최초 제보가 필요한 매장이에요. '
                        '제보하면 스탬프를 2개 받을 수 있어요.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          _LegendItem(color: Color(0xFF26BC7D), label: '여유로움'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFFFBF00), label: '약간혼잡'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFEF4444), label: '자리없음'),
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
  final Color? activeBg;
  final Color? activeText;
  /// 라벨 앞에 표시할 아이콘 (선택)
  final IconData? leadingIcon;
  /// 라벨 뒤에 표시할 아이콘 (선택, leadingIcon과 동시 사용 가능)
  final IconData? trailingIcon;
  final String? labelFontFamily;
  final double labelFontSize;
  final double verticalPadding;
  final bool showArrow;

  const _MapFilterChip({
    required this.label,
    required this.active,
    required this.open,
    required this.onTap,
    this.restingBg,
    this.restingText,
    this.activeBg,
    this.activeText,
    this.leadingIcon,
    this.trailingIcon,
    this.labelFontFamily,
    this.labelFontSize = 12,
    this.verticalPadding = 8,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final on = active || open;
    final restBg = restingBg ?? Colors.white;
    final restText = restingText ?? const Color(0xFF374151);
    final bgColor = on ? (activeBg ?? AppColors.primaryCta) : restBg;
    final textColor = on ? (activeText ?? Colors.white) : restText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: bgColor,
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
                color: textColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontFamily: labelFontFamily,
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w900,
                    color: textColor)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 3),
              Icon(
                trailingIcon,
                size: 14,
                color: textColor,
              ),
            ],
            if (showArrow) ...[
              const SizedBox(width: 4),
              Icon(
                open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 12,
                color: textColor,
              ),
            ],
          ],
        ),
      ),
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
                      color: const Color(0xFFF3F4F6),
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
                              color: Color(0xFF000000)),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF000000))),
                        const SizedBox(height: 2),
                        Row(children: [
                          Flexible(
                            child: Text('${r.area} · ',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF9CA3AF))),
                          ),
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
                        border: Border.all(color: AppColors.primaryCta, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation_outlined,
                                size: 16, color: AppColors.primaryCta),
                            SizedBox(width: 6),
                            Text('길찾기',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryCta)),
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
                          color: AppColors.primaryCta,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(noReport ? '스탬프 2개 받기' : '혼잡도 제보하기',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
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
