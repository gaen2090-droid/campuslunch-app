import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/lunch_fairy_recommender.dart';
import '../widgets/restaurant_image.dart';
import 'detail_screen.dart';

/// 홈 11~14시 배너. 평일 점심시간에만 노출한다 (판정은 [isFairyBannerTime]).
class LunchFairyBanner extends StatelessWidget {
  final VoidCallback onTap;

  /// 마이 탭처럼 다른 카드와 나란히 놓일 때: 회색 테두리를 두르고 부제를 뺀다.
  final bool compact;
  const LunchFairyBanner({super.key, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          // 홈은 연두색, 마이 탭은 다른 카드와 같은 흰색.
          color: compact ? Colors.white : const Color(0xFFE6F3EC),
          borderRadius: BorderRadius.circular(compact ? 20 : 18),
          border: compact ? Border.all(color: const Color(0xFFE5E7EB)) : null,
          boxShadow: compact
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Image.asset(_kFairyAsset, width: 46, height: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 홈 배너는 Ok단단체, 마이 탭은 다른 카드 행과 같은 프리텐다드.
                  Text(
                    compact ? '점메추 요정과 점심 메뉴 고르기' : '점메추 요정',
                    style: compact
                        ? const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF000000),
                          )
                        : const TextStyle(
                            fontFamily: 'OkDanDan',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    const Text(
                      '3초만에 점심 메뉴 추천해드릴게요!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 마이 탭에서는 다른 카드 행(MyPageSectionRow)과 같은 회색 화살표.
            compact
                ? const Icon(Icons.chevron_right,
                    size: 18, color: Color(0xFFD1D5DB))
                : const Icon(Icons.chevron_right, color: Color(0xFF26BC7D)),
          ],
        ),
      ),
    );
  }
}

const String _kFairyAsset = 'assets/images/fairy.png';

enum _Phase { questions, thinking, result, exhausted, nothingOpen, error }

class LunchFairyScreen extends StatefulWidget {
  const LunchFairyScreen({super.key});

  @override
  State<LunchFairyScreen> createState() => _LunchFairyScreenState();
}

class _LunchFairyScreenState extends State<LunchFairyScreen> {
  static const _kCuisine = 'fairy_cuisine';
  static const _kBudget = 'fairy_budget';
  static const _kWalk = 'fairy_walk';
  static const _kArea = 'fairy_area'; // 예전 버전(단일 선택) 값
  static const _kAreas = 'fairy_areas';
  static const _kFriend = 'fairy_friend';
  static const _kCompanion = 'fairy_companion';

  static const _cuisines = ['한식', '중식', '일식', '양식', '분식', '아시아'];
  static const _budgets = <(String, int?)>[
    ('~8천', 8000),
    ('~1만', 10000),
    ('~1만3천', 13000),
    ('상관없음', null),
  ];
  static const _walks = <(String, int?)>[
    ('상관없음', null),
    ('도보 5분', 5),
    ('도보 10분', 10),
  ];

  String? _cuisine;
  int? _budget;
  int? _walk;

  /// 흑석(=정문+중문) / 상도(=후문). 복수 선택 가능하고, 도보 조건과 함께 쓸 수 있다.
  /// 값은 매장의 area 그대로(정문·중문·후문)이다.
  final Set<String> _areas = {};

  static const _heukseokAreas = ['정문', '중문'];
  static const _sangdoAreas = ['후문'];
  FairyCompanion _companion = FairyCompanion.solo;

  /// 앱 위치 모드 ON + OS 권한 허용일 때만 거리 질문을 고를 수 있다.
  bool _locationReady = false;
  _Phase _phase = _Phase.questions;
  FairyPick? _pick;
  FairyRequest? _lastRequest;
  FairyPosition? _lastPosition;
  final Set<String> _seen = {};
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _restoreAnswers();
    _checkLocation();
  }

  Future<void> _restoreAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _cuisine = prefs.getString(_kCuisine);
        _budget = prefs.containsKey(_kBudget) ? prefs.getInt(_kBudget) : null;
        _walk = prefs.containsKey(_kWalk) ? prefs.getInt(_kWalk) : null;
        final savedAreas = prefs.getStringList(_kAreas) ??
            [if (prefs.getString(_kArea) != null) prefs.getString(_kArea)!];
        _areas
          ..clear()
          ..addAll(savedAreas.where((a) => a == '정문' || a == '중문' || a == '후문'));
        // 흑석은 정문+중문을 함께 다룬다. 예전에 정문만 저장된 값도 흑석 전체로 맞춘다.
        if (_areas.contains('정문') || _areas.contains('중문')) {
          _areas.addAll(_heukseokAreas);
        }
        final saved = prefs.getString(_kCompanion);
        _companion = FairyCompanion.values.firstWhere(
          (c) => c.name == saved,
          // 예전 버전(혼밥/친구랑 bool) 답변도 이어받는다.
          orElse: () => (prefs.getBool(_kFriend) ?? false)
              ? FairyCompanion.friend
              : FairyCompanion.solo,
        );
      });
    } catch (_) {
      // 저장된 답변이 없어도 기본값(상관없음/혼밥)으로 동작한다.
    }
  }

  Future<void> _saveAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Future<void> putInt(String k, int? v) =>
          v == null ? prefs.remove(k) : prefs.setInt(k, v);
      if (_cuisine == null) {
        await prefs.remove(_kCuisine);
      } else {
        await prefs.setString(_kCuisine, _cuisine!);
      }
      await putInt(_kBudget, _budget);
      await putInt(_kWalk, _walk);
      await prefs.remove(_kArea);
      if (_areas.isEmpty) {
        await prefs.remove(_kAreas);
      } else {
        await prefs.setStringList(_kAreas, _areas.toList());
      }
      await prefs.setString(_kCompanion, _companion.name);
    } catch (_) {}
  }

  Future<void> _checkLocation() async {
    final provider = context.read<AppProvider>();
    var ready = false;
    if (provider.locationMode) {
      try {
        final p = await Geolocator.checkPermission();
        ready = p == LocationPermission.always ||
            p == LocationPermission.whileInUse;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _locationReady = ready;
      if (!ready) _walk = null;
    });
  }

  /// 칩 하나가 여러 지역(흑석 = 정문+중문)을 묶는다. 모두 선택돼 있으면 해제, 아니면 모두 선택.
  void _toggleAreas(List<String> group) {
    if (_areas.containsAll(group)) {
      _areas.removeAll(group);
    } else {
      _areas.addAll(group);
    }
  }

  /// 도보 5분/10분 선택. 위치가 꺼져 있으면 OS 위치 권한 팝업을 띄우고, 허용되면 선택한다.
  /// 이미 "다시 묻지 않음"으로 거부해 OS가 팝업을 더 띄울 수 없으면 설정 이동을 안내한다.
  Future<void> _selectWalk(int minutes) async {
    if (!_locationReady) {
      await _enableLocation();
      if (!mounted) return;
      if (!_locationReady) {
        await _showLocationDeniedDialog();
        return;
      }
    }
    // 이미 고른 도보 칩을 다시 누르면 해제한다.
    setState(() => _walk = _walk == minutes ? null : minutes);
  }

  Future<void> _showLocationDeniedDialog() async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('위치 권한이 필요해요'),
        content: const Text(
          '도보 거리로 고르려면 현재 위치가 필요해요.\n설정에서 위치 권한을 허용해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
    }
  }

  Future<void> _enableLocation() async {
    await context.read<AppProvider>().enableLocation();
    await _checkLocation();
  }

  Future<FairyPosition?> _currentPosition() async {
    if (!_locationReady) return null;
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return null;
      return FairyPosition(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _start() async {
    final provider = context.read<AppProvider>();
    setState(() => _phase = _Phase.thinking);
    _seen.clear();
    await _saveAnswers();

    // 사장님이 방금 고친 메뉴·영업시간·혼잡도가 바로 반영되도록 매번 최신 데이터로 계산한다.
    // 갱신에 실패해도 가지고 있는 목록으로 계속 진행한다.
    // 목록만 받고(푸시 동기화 등은 기다리지 않음) 시간 제한을 둔다. 느리거나 실패해도
    // 가지고 있는 목록으로 계속 진행한다.
    try {
      await provider.reloadRestaurantsOnly().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Fairy] reload skipped: $e');
    }
    try {
      _lastPosition =
          await _currentPosition().timeout(const Duration(seconds: 7));
    } catch (e) {
      debugPrint('[Fairy] position skipped: $e');
      _lastPosition = null;
    }
    _lastRequest = FairyRequest(
      cuisine: _cuisine,
      budgetLimit: _budget,
      walkMinutes: _lastPosition == null ? null : _walk,
      areas: _areas.toSet(),
      companion: _companion,
    );
    if (!mounted) return;
    _recommend();
  }

  void _recommend() {
    final provider = context.read<AppProvider>();
    final req = _lastRequest;
    if (req == null) return;
    final FairyOutcome outcome;
    try {
      outcome = fairyRecommend(
        provider.restaurants,
        req,
        now: DateTime.now(),
        position: _lastPosition,
        seenIds: _seen,
        bookmarkIds: provider.bookmarks,
        random: _random,
      );
    } catch (e, st) {
      // 어떤 경우에도 로딩에서 빠져나오지 못하는 일이 없게 오류 화면으로 보낸다.
      debugPrint('[Fairy] recommend failed: $e');
      debugPrint('$st');
      setState(() {
        _pick = null;
        _phase = _Phase.error;
      });
      return;
    }
    setState(() {
      if (outcome.pick != null) {
        _pick = outcome.pick;
        _seen.add(outcome.pick!.restaurant.id);
        _phase = _Phase.result;
      } else {
        _pick = null;
        _phase = outcome.nothingOpen ? _Phase.nothingOpen : _Phase.exhausted;
      }
    });
  }

  Future<void> _reroll() async {
    setState(() => _phase = _Phase.thinking);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _recommend();
  }

  void _openDetail(Restaurant r) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)),
      );

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기한 매장 화면과 같은 AppBar 구성: 뒤로가기 IconButton(18) + titleSpacing 0 +
    // 제목 Pretendard 18 / w700 / letterSpacing -0.5, 왼쪽 정렬.
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '점메추 요정',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.questions => _buildQuestions(),
          _Phase.thinking => _buildThinking(),
          _Phase.result => _buildResult(),
          _Phase.exhausted => _buildMessage(
              '더 보여드릴 곳이 없어요.\n조건을 바꿔서 다시 골라볼까요?',
            ),
          _Phase.error => _buildMessage(
              '앗, 고르다가 문제가 생겼어요.\n잠시 후 다시 시도해 주세요!',
            ),
          _Phase.nothingOpen => _buildMessage(
              '지금은 영업 중인 곳을 찾지 못했어요.\n조금 있다가 다시 와 주세요!',
            ),
        },
      ),
    );
  }

  // ── 질문 ──
  Widget _buildQuestions() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(_kFairyAsset, width: 84, height: 84),
        ),
        const SizedBox(height: 8),
        const Text(
          '오늘 점심 메뉴\n제가 골라드릴게요!',
          style: TextStyle(
            fontFamily: 'OkDanDan',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 24),
        _section('뭐가 땡기시나요?', [
          _chip('상관없음', _cuisine == null, () => setState(() => _cuisine = null)),
          for (final c in _cuisines)
            _chip(c, _cuisine == c, () => setState(() => _cuisine = c)),
        ]),
        _section('1인당 예산은 얼마인가요?', [
          for (final (label, value) in _budgets)
            _chip(label, _budget == value, () => setState(() => _budget = value)),
        ]),
        _section(
          '위치는 어디가 좋을까요?',
          [
            for (final (label, value) in _walks)
              _chip(
                label,
                // "상관없음"은 도보도 지역도 고르지 않았을 때만 선택된 상태
                value == null ? (_walk == null && _areas.isEmpty) : _walk == value,
                () {
                  if (value == null) {
                    setState(() {
                      _walk = null;
                      _areas.clear();
                    });
                  } else {
                    // 도보 조건은 위치가 필요하다. 권한이 없으면 OS 허용 팝업을 띄운다.
                    unawaited(_selectWalk(value));
                  }
                },
              ),
            // 흑석(정문) / 상도(후문): 위치 권한 없이도 고를 수 있고, 둘 다 고를 수 있다.
            // 도보 5분/10분과 함께 고르면 "그 지역 안에서 도보 N분 이내"가 된다.
            _chip(
              '흑석',
              _areas.containsAll(_heukseokAreas),
              () => setState(() => _toggleAreas(_heukseokAreas)),
            ),
            _chip(
              '상도',
              _areas.containsAll(_sangdoAreas),
              () => setState(() => _toggleAreas(_sangdoAreas)),
            ),
          ],
          footer: _locationReady
              ? null
              : _LocationHint(onEnable: _enableLocation),
        ),
        _section('누구랑 드시나요?', [
          _chip('혼밥', _companion == FairyCompanion.solo,
              () => setState(() => _companion = FairyCompanion.solo)),
          _chip('친구랑', _companion == FairyCompanion.friend,
              () => setState(() => _companion = FairyCompanion.friend)),
          _chip('밥약', _companion == FairyCompanion.date,
              () => setState(() => _companion = FairyCompanion.date)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCta,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _start,
            child: const Text(
              '골라주세요!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> chips, {Widget? footer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          // 칩은 항상 한 줄. 화면보다 길면(음식종류) 옆으로 밀어서 볼 수 있다.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  chips[i],
                ],
              ],
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 8), footer],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {bool enabled = true}) {
    final Color bg;
    final Color fg;
    if (!enabled) {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFFD1D5DB);
    } else if (selected) {
      bg = AppColors.primaryCta;
      fg = Colors.white;
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF374151);
    }
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg),
        ),
      ),
    );
  }

  // ── 생각 중 ──
  Widget _buildThinking() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(_kFairyAsset, width: 110, height: 110),
          SizedBox(height: 12),
          Text(
            '요정이 고르는 중이에요…',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
          ),
        ],
      ),
    );
  }

  // ── 결과 ──
  Widget _buildResult() {
    final pick = _pick!;
    final r = pick.restaurant;
    // 30분 넘은 제보는 뱃지를 아예 띄우지 않는다 (경과 분도 지금 시각 기준으로 계산).
    final badgeMinutes = pick.tier == FairyTier.reportTarget
        ? fairyCrowdBadgeMinutes(r, DateTime.now())
        : null;
    final showCrowd = badgeMinutes != null;
    final meta = crowdStatusMeta(r.status);
    // 가격 필터는 엔진에서 끝났으니, 화면에는 대표메뉴를 가격과 상관없이 모두 보여준다.
    final signatures = fairySignatureMenus(r);
    final menu = pick.menu;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          _headline(pick),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.35),
        ),
        if (pick.relaxed.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _relaxedNote(pick.relaxed),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.imageUrl.isNotEmpty)
                SizedBox(
                  height: 160,
                  child: RestaurantImage(
                    url: r.imageUrl,
                    fallback: () => Container(color: const Color(0xFFF3F4F6)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.area} · ${r.category}'
                      '${pick.walkMinutes != null ? ' · 걸어서 약 ${pick.walkMinutes}분' : ''}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    if (showCrowd) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(meta.bgColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${meta.label} · $badgeMinutes분 전',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(meta.color),
                          ),
                        ),
                      ),
                    ],
                    if (signatures.isNotEmpty || menu != null) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signatures.isNotEmpty ? '대표메뉴' : '추천 메뉴',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final m in signatures.isNotEmpty
                                    ? signatures
                                    : [menu!])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      m.price > 0
                                          ? (m.hasPriceRange
                                              ? '${m.name} · ${_won(m.price)} ~ ${_won(m.priceMax)}'
                                              : '${m.name} · ${_won(m.price)}')
                                          : m.name,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCta,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _openDetail(r),
            child: const Text(
              '매장 자세히 보기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _reroll,
                child: const Text('다른 곳 볼래요', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => setState(() => _phase = _Phase.questions),
                child: const Text('조건 바꾸기', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(_kFairyAsset, width: 96, height: 96),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCta,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => setState(() => _phase = _Phase.questions),
              child: const Text('조건 바꾸기'),
            ),
          ],
        ),
      ),
    );
  }

  // 말투는 여기서만 만든다. 엔진은 이유 코드만 돌려준다.
  String _headline(FairyPick pick) {
    final r = pick.restaurant;
    switch (pick.reason) {
      case FairyReason.freshRelaxed:
        return '지금 ${r.name} 여유로워요!';
      case FairyReason.freshModerate:
        return '${r.name}, 조금 붐비지만 자리는 있다고 해요.';
      case FairyReason.nearby:
        final w = pick.walkMinutes;
        return '${r.name}, ${w != null ? '걸어서 $w분이면 가요!' : '가까워요!'}';
      case FairyReason.soloFriendly:
        return '${r.name}, 혼자 가기 편한 곳이에요.';
      case FairyReason.dateFriendly:
        return '${r.name}, 밥약하기 좋은 곳이에요.';
      case FairyReason.general:
        return '${r.name} 어떠세요?';
    }
  }

  String _relaxedNote(List<FairyRelax> relaxed) {
    final parts = <String>[];
    for (final x in relaxed) {
      switch (x) {
        case FairyRelax.budget:
          parts.add('예산');
        case FairyRelax.cuisine:
          parts.add('음식종류');
        case FairyRelax.distance:
          parts.add('거리');
      }
    }
    return '조건에 딱 맞는 곳이 없어서 ${parts.join('·')} 조건을 조금 넓혀봤어요!';
  }

  String _won(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$buf원';
  }
}

class _LocationHint extends StatelessWidget {
  final VoidCallback onEnable;
  const _LocationHint({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '위치를 켜면 가까운 곳 위주로 고를 수 있어요.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ),
        GestureDetector(
          onTap: onEnable,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              '위치 켜기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF26BC7D),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
