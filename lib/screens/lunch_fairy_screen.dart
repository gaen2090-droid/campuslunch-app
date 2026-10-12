import 'dart:math' as math;

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
  const LunchFairyBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F3EC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Text('🧚', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '점심메뉴 정해주는 요정',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '뭐 먹을지 고민이면 3초만 눌러봐!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF26BC7D)),
          ],
        ),
      ),
    );
  }
}

enum _Phase { questions, thinking, result, exhausted, nothingOpen }

class LunchFairyScreen extends StatefulWidget {
  const LunchFairyScreen({super.key});

  @override
  State<LunchFairyScreen> createState() => _LunchFairyScreenState();
}

class _LunchFairyScreenState extends State<LunchFairyScreen> {
  static const _kCuisine = 'fairy_cuisine';
  static const _kBudget = 'fairy_budget';
  static const _kWalk = 'fairy_walk';
  static const _kFriend = 'fairy_friend';

  static const _cuisines = ['한식', '중식', '일식', '양식', '분식', '아시아'];
  static const _budgets = <(String, int?)>[
    ('~8천', 8000),
    ('~1만', 10000),
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
  bool _friend = false;

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
        _friend = prefs.getBool(_kFriend) ?? false;
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
      await prefs.setBool(_kFriend, _friend);
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
    try {
      await provider.refreshRestaurants();
    } catch (_) {}
    _lastPosition = await _currentPosition();
    _lastRequest = FairyRequest(
      cuisine: _cuisine,
      budgetLimit: _budget,
      walkMinutes: _lastPosition == null ? null : _walk,
      withFriend: _friend,
    );
    if (!mounted) return;
    _recommend();
  }

  void _recommend() {
    final provider = context.read<AppProvider>();
    final req = _lastRequest;
    if (req == null) return;
    final outcome = fairyRecommend(
      provider.restaurants,
      req,
      now: DateTime.now(),
      position: _lastPosition,
      seenIds: _seen,
      bookmarkIds: provider.bookmarks,
      random: _random,
    );
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          '점심메뉴 정해주는 요정',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.questions => _buildQuestions(),
          _Phase.thinking => _buildThinking(),
          _Phase.result => _buildResult(),
          _Phase.exhausted => _buildMessage(
              '더 보여줄 곳이 없어.\n조건을 바꿔서 다시 골라볼까?',
            ),
          _Phase.nothingOpen => _buildMessage(
              '지금은 영업 중인 곳을 못 찾았어.\n조금 있다가 다시 와줘!',
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
        const Text('🧚', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        const Text(
          '오늘 점심 뭐 먹을지\n내가 골라줄게!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.3),
        ),
        const SizedBox(height: 4),
        const Text(
          '안 골라도 돼. 상관없으면 그냥 눌러!',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 24),
        _section('뭐 땡겨?', [
          _chip('상관없음', _cuisine == null, () => setState(() => _cuisine = null)),
          for (final c in _cuisines)
            _chip(c, _cuisine == c, () => setState(() => _cuisine = c)),
        ]),
        _section('예산은?', [
          for (final (label, value) in _budgets)
            _chip(label, _budget == value, () => setState(() => _budget = value)),
        ]),
        _section(
          '얼마나 가까워야 해?',
          [
            for (final (label, value) in _walks)
              _chip(
                label,
                _walk == value,
                () => setState(() => _walk = value),
                enabled: _locationReady || value == null,
              ),
          ],
          footer: _locationReady
              ? null
              : _LocationHint(onEnable: _enableLocation),
        ),
        _section('누구랑 먹어?', [
          _chip('혼밥', !_friend, () => setState(() => _friend = false)),
          _chip('친구랑', _friend, () => setState(() => _friend = true)),
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
              '요정아 골라줘!',
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
          Wrap(spacing: 8, runSpacing: 8, children: chips),
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🧚', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            '요정이 고르는 중…',
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
    final showCrowd = pick.tier == FairyTier.reportTarget && r.hasCrowdUpdate;
    final meta = crowdStatusMeta(r.status);
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
                          '${meta.label} · ${r.updated}분 전',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(meta.color),
                          ),
                        ),
                      ),
                    ],
                    if (menu != null) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text('추천 메뉴', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              menu.price > 0
                                  ? '${menu.name} · ${_won(menu.price)}'
                                  : menu.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
              '갈래!',
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
                child: const Text('다른 데!', style: TextStyle(fontWeight: FontWeight.w800)),
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
            const Text('🧚', style: TextStyle(fontSize: 48)),
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
    final menu = pick.menu;
    final eat = menu == null ? '여기 가봐!' : '가서 ${menu.name} 먹어!';
    switch (pick.reason) {
      case FairyReason.freshRelaxed:
        return '지금 ${r.name} 여유로워!\n$eat';
      case FairyReason.freshModerate:
        return '${r.name}, 조금 붐비지만 자리는 있대.\n$eat';
      case FairyReason.nearby:
        final w = pick.walkMinutes;
        return '${r.name}, ${w != null ? '걸어서 $w분이면 가!' : '가까워!'}\n$eat';
      case FairyReason.soloFriendly:
        return '${r.name}, 혼자 가기 편한 곳이야.\n$eat';
      case FairyReason.general:
        return '${r.name} 어때?\n$eat';
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
    return '조건에 딱 맞는 곳이 없어서 ${parts.join('·')} 조건을 조금 넓혀봤어!';
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
