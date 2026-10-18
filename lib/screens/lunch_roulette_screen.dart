import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart'
    show Button, Link, ShareClient, TextTemplate;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_colors.dart';
import '../constants/app_links.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/lunch_fairy_recommender.dart';
import '../utils/lunch_roulette.dart';
import '../widgets/restaurant_image.dart';
import '../widgets/share_sheet.dart'
    show buildShareLink, launchRestaurantKakaoShare;
import 'detail_screen.dart';

/// 점메추 요정 아래에 놓는 룰렛 배너. 홈은 요정 배너와 같은 시간대에만 보인다.
class LunchRouletteBanner extends StatelessWidget {
  final VoidCallback onTap;

  /// 마이 탭처럼 다른 카드와 나란히 놓일 때: 흰 배경 + 회색 테두리, 부제 없음.
  final bool compact;
  const LunchRouletteBanner({
    super.key,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(20, compact ? 0 : 0, 20, 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: compact ? Colors.white : const Color(0xFFFFF4CC),
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
            Image.asset('assets/images/roulette.png', width: 46, height: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '식당 룰렛 돌리기',
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
                      '고민될 땐 돌려서 정해요!',
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
            compact
                ? const Icon(Icons.chevron_right,
                    size: 18, color: Color(0xFFD1D5DB))
                : const Icon(Icons.chevron_right, color: Color(0xFFB45309)),
          ],
        ),
      ),
    );
  }
}

class LunchRouletteScreen extends StatefulWidget {
  /// 친구가 카톡으로 보낸 후보(매장 linkNo). 있으면 "같이 고르기"에 미리 채워 연다.
  final List<int> presetLinkNos;
  const LunchRouletteScreen({super.key, this.presetLinkNos = const []});

  @override
  State<LunchRouletteScreen> createState() => _LunchRouletteScreenState();
}

class _LunchRouletteScreenState extends State<LunchRouletteScreen>
    with SingleTickerProviderStateMixin {
  static const _cuisineList = ['한식', '중식', '일식', '양식', '분식', '아시아'];
  static const _spinDuration = Duration(milliseconds: 3800);

  final math.Random _rng = math.Random();
  late final AnimationController _spin = AnimationController(vsync: this)
    ..addListener(() => setState(() {}))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _onStopped();
    });

  /// 0 랜덤 배정, 1 같이 고르기
  int _tab = 0;
  bool _loading = true;

  // 랜덤 배정
  final Set<String> _cuisines = {};
  bool _mixIn = false;
  RouletteDeal? _deal;

  // 같이 고르기
  final Set<String> _picked = {};

  /// 같이 고르기 목록의 음식 종류 필터 (비어 있으면 전체). 고른 매장은 필터와 무관하게 유지된다.
  final Set<String> _pickFilter = {};
  bool _pickWheelStage = false;
  List<Restaurant> _pickWheel = const [];

  // 룰렛
  double _rotation = 0;
  double _from = 0;
  double _to = 0;
  int? _winner;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  List<Restaurant> get _all => context.read<AppProvider>().restaurants;

  /// 어드민 운영 지표용 사용 기록. 실패해도 화면에는 영향이 없다.
  void _track(String action, {Map<String, dynamic>? metadata}) {
    unawaited(context
        .read<AppProvider>()
        .recordFeatureEvent('roulette', action, metadata: metadata));
  }

  /// 사장님이 방금 고친 영업 상태가 바로 반영되도록 최신 목록으로 칸을 구성한다.
  Future<void> _load() async {
    try {
      await context
          .read<AppProvider>()
          .reloadRestaurantsOnly()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Roulette] reload skipped: $e');
    }
    if (!mounted) return;
    final preset = widget.presetLinkNos.toSet();
    _track(preset.isNotEmpty ? 'preset_open' : 'open');
    setState(() {
      _loading = false;
      if (preset.isNotEmpty) {
        _tab = 1;
        final now = DateTime.now();
        for (final r in _all) {
          if (r.linkNo > 0 &&
              preset.contains(r.linkNo) &&
              fairyIsEligible(r, now)) {
            _picked.add(r.id);
          }
        }
        while (_picked.length > rouletteMaxSlots) {
          _picked.remove(_picked.last);
        }
      }
      _redeal();
    });
  }

  void _redeal({bool avoidCurrent = false}) {
    // "후보 바꾸기"는 지금 칸의 매장을 되도록 피해 새로 뽑되, 칸 수는 유지한다.
    final avoid = avoidCurrent
        ? (_deal?.slots.map((r) => r.id).toSet() ?? <String>{})
        : <String>{};
    _deal = dealRoulette(
      _all,
      now: DateTime.now(),
      cuisines: _cuisines,
      mixIn: _mixIn,
      avoidIds: avoid,
      random: _rng,
    );
    _winner = null;
  }

  List<Restaurant> get _wheel {
    if (_tab == 1) return _pickWheelStage ? _pickWheel : const [];
    return _deal?.slots ?? const [];
  }

  bool get _canSpin => !_spinning && _wheel.length >= rouletteMinSlots;

  void _startSpin() {
    final n = _wheel.length;
    if (n < rouletteMinSlots || _spinning) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    // 결과를 먼저 균등 랜덤으로 정하고, 룰렛은 그 칸이 화살표 아래에 오도록 돌린다.
    final winner = rouletteWinnerIndex(n, _rng);
    final sweep = 2 * math.pi / n;
    final jitter = (_rng.nextDouble() - 0.5) * 0.6; // 칸 안에서 약간 비껴 멈춘다
    final target = -(winner + 0.5 + jitter) * sweep;
    final current = _rotation % (2 * math.pi);
    var delta = (target - current) % (2 * math.pi);
    if (delta < 0) delta += 2 * math.pi;
    final turns = reduce ? 0 : 5 + _rng.nextInt(2);
    _track('spin', metadata: {'tab': _tab == 0 ? 'random' : 'pick'});
    setState(() {
      _winner = winner;
      _spinning = true;
      _from = _rotation;
      _to = _rotation + turns * 2 * math.pi + delta;
    });
    _spin.duration = reduce ? const Duration(milliseconds: 200) : _spinDuration;
    _spin.forward(from: 0);
  }

  double get _angle => _spinning
      ? _from + (_to - _from) * Curves.easeOutCubic.transform(_spin.value)
      : _rotation;

  void _onStopped() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _rotation = _to;
      _spinning = false;
    });
    _track('result_shown', metadata: {'tab': _tab == 0 ? 'random' : 'pick'});
  }

  void _openDetail(Restaurant r) {
    _track('detail_click');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)),
    );
  }

  // ── 화면 ──
  @override
  Widget build(BuildContext context) {
    final inPickWheel = _tab == 1 && _pickWheelStage;
    return PopScope(
      canPop: !(inPickWheel && !_spinning),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inPickWheel && !_spinning) _backToPicking();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Color(0xFF000000)),
            onPressed: () {
              if (inPickWheel && !_spinning) {
                _backToPicking();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          titleSpacing: 0,
          title: const Text(
            '식당 룰렛',
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (!inPickWheel) _tabs(),
                    Expanded(
                      child: _tab == 0
                          ? _buildRandomTab()
                          : (_pickWheelStage
                              ? _buildWheelView(showReroll: false)
                              : _buildPickList()),
                    ),
                    _bottomBar(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tabs() {
    Widget tab(int i, String label) {
      final selected = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: _spinning
              ? null
              : () => setState(() {
                    _tab = i;
                    _winner = null;
                    _pickWheelStage = false;
                  }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryCta : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: [
          tab(0, '랜덤 배정'),
          const SizedBox(width: 8),
          tab(1, '같이 고르기'),
        ],
      ),
    );
  }

  // ── 랜덤 배정 ──
  Widget _buildRandomTab() {
    final deal = _deal;
    final notice = deal == null ? null : rouletteNotice(deal, _cuisines);
    final blocked = deal != null && !deal.canSpin;
    final mixAction = blocked && !_mixIn && _cuisines.isNotEmpty
        ? (
            '다른 음식도 섞어서 돌리기',
            () {
              setState(() {
                _mixIn = true;
                _redeal();
              });
            }
          )
        : null;
    return Column(
      children: [
        _cuisineChips(),
        if (notice != null && !blocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _notice(notice),
          ),
        Expanded(
          child: blocked
              // 돌릴 수 없을 때는 안내를 남은 영역 한가운데에 둔다.
              ? Center(
                  child: notice == null
                      ? const SizedBox.shrink()
                      : _notice(notice, action: mixAction),
                )
              : _buildWheelView(showReroll: true),
        ),
      ],
    );
  }

  /// 위의 탭 줄과 좌우 끝을 맞춘 칩 줄. 글자 수에 비례해 폭을 나눠 한 줄을 꽉 채운다.
  Widget _chipRow(List<(String, bool, VoidCallback)> chips) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: chips[i].$1.length + 2,
              child: GestureDetector(
                onTap: _spinning ? null : chips[i].$3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chips[i].$2
                        ? AppColors.primaryCta
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      chips[i].$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: chips[i].$2
                            ? Colors.white
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cuisineChips() {
    return _chipRow([
      (
        '상관없음',
        _cuisines.isEmpty,
        () {
          setState(() {
            _cuisines.clear();
            _mixIn = false;
            _redeal();
          });
        }
      ),
      for (final c in _cuisineList)
        (
          c,
          _cuisines.contains(c),
          () {
            setState(() {
              if (!_cuisines.remove(c)) _cuisines.add(c);
              _mixIn = false;
              _redeal();
            });
          }
        ),
    ]);
  }

  Widget _notice(String text, {(String, VoidCallback)? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: action.$2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Text(
                  action.$1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 룰렛 + 결과 ──
  Widget _buildWheelView({required bool showReroll}) {
    final wheel = _wheel;
    final winner = _winner;
    final result = (!_spinning && winner != null && winner < wheel.length)
        ? wheel[winner]
        : null;
    return LayoutBuilder(
      builder: (context, c) {
        // 화면 폭에 거의 꽉 차게 (좌우 여백 8). 너무 큰 태블릿만 상한을 둔다.
        final size = math.min(c.maxWidth - 16, 520.0);
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          children: [
            Center(
              child: SizedBox(
                width: size,
                height: size + 22,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 22,
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: _WheelPainter(
                          labels: [for (final r in wheel) r.name],
                          rotation: _angle,
                          highlight: _spinning ? null : winner,
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      child: Icon(Icons.arrow_drop_down,
                          size: 52, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ),
            if (showReroll && !_spinning) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _redeal(avoidCurrent: true)),
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: const Text('후보 바꾸기',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280)),
                ),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _resultCard(result),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _resultCard(Restaurant r) {
    final fresh = isFreshRelaxed(r, DateTime.now());
    final menus = fairySignatureMenus(r);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryCta, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.imageUrl.isNotEmpty)
            SizedBox(
              height: 140,
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
                const Text(
                  '오늘의 점심은!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.area} · ${r.category}',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                if (fresh) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F3EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '바로입장 · 최근 제보',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F8F5F),
                      ),
                    ),
                  ),
                ],
                if (menus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '대표메뉴  ${menus.map((m) => m.name).join(' · ')}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _openDetail(r),
                    child: const Text('매장 자세히 보기',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: const Color(0xFF3C1E1E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _shareResult(r),
                    icon: const Icon(Icons.chat_bubble, size: 16),
                    label: const Text('친구에게 결과 공유하기',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 룰렛이 정한 매장을 카카오톡으로 공유한다. 카카오톡을 쓸 수 없으면 기본 공유창으로 넘어간다.
  Future<void> _shareResult(Restaurant r) async {
    _track('result_share_click',
        metadata: {'tab': _tab == 0 ? 'random' : 'pick'});
    final menus = fairySignatureMenus(r).map((m) => m.name).toList();
    final menuLine = menus.isNotEmpty ? '\n대표메뉴: ${menus.join(' · ')}' : '';
    const closing = '캠퍼스런치에서 같이 돌려봐요.';
    final title = '오늘 점심, 식당 룰렛이 고른 곳은 ${r.name}!';
    final description = menuLine.isEmpty ? closing : '${menuLine.trim()}\n$closing';
    final text = '$title\n$description';
    try {
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        await launchRestaurantKakaoShare(
          restaurant: r,
          title: title,
          description: description,
        );
        return;
      }
      await Share.share('$text\n${buildShareLink(r)}');
    } catch (e) {
      debugPrint('[Roulette] result share failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유를 열지 못했어요. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  // ── 같이 고르기 ──

  /// 지금 고른 후보를 카카오톡으로 친구에게 보낸다. 친구가 링크를 열면
  /// 이 후보가 미리 채워진 "같이 고르기"가 열리고, 거기에 자기 후보를 더해 돌릴 수 있다.
  Future<void> _sendPicksToFriend() {
    final byId = {for (final r in _all) r.id: r};
    final picked = [
      for (final id in _picked)
        if (byId[id] != null) byId[id]!,
    ];
    return _shareCandidates(
      picked,
      emptyMessage: _picked.isEmpty ? '먼저 후보를 골라주세요.' : '보낼 수 있는 후보가 없어요.',
    );
  }

  Future<void> _shareCandidates(
    List<Restaurant> candidates, {
    required String emptyMessage,
  }) async {
    _track('candidates_share_click');
    final withLink = candidates.where((r) => r.linkNo > 0).toList();
    if (withLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    // 카카오 텍스트 템플릿은 길이 제한이 있어 이름은 일부만 싣는다.
    final names = <String>[];
    var length = 0;
    for (final r in withLink) {
      if (length + r.name.length > 70) break;
      names.add(r.name);
      length += r.name.length + 3;
    }
    final rest = withLink.length - names.length;
    final text = '식당 룰렛 후보를 골랐어요!\n'
        '${names.join(' · ')}${rest > 0 ? ' 외 $rest곳' : ''}\n'
        '가고 싶은 곳을 더 골라서 같이 돌려봐요.';

    final params =
        AppLinks.rouletteExecutionParams([for (final r in withLink) r.linkNo]);
    final url = Uri.parse(AppLinks.homeUrl());
    final link = Link(
      webUrl: url,
      mobileWebUrl: url,
      androidExecutionParams: params,
      iosExecutionParams: params,
    );
    final template = TextTemplate(
      text: text,
      link: link,
      buttons: [Button(title: '후보 보러 가기', link: link)],
    );
    try {
      if (!await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        throw StateError('kakao not available');
      }
      final uri = await ShareClient.instance.shareDefault(template: template);
      await ShareClient.instance.launchKakaoTalk(uri);
    } catch (e) {
      debugPrint('[Roulette] share failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카카오톡 공유에 실패했어요. 카카오톡 설치를 확인해주세요.'),
        ),
      );
    }
  }

  void _backToPicking() => setState(() {
        _pickWheelStage = false;
        _winner = null;
      });

  Widget _buildPickList() {
    final all = rouletteEligible(_all, DateTime.now());
    final list = _pickFilter.isEmpty
        ? all
        : all.where((r) => _pickFilter.contains(r.category)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '친구랑 같이 보면서 가고 싶은 곳을 골라주세요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              Text(
                '${_picked.length}/$rouletteMaxSlots',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _picked.length >= rouletteMinSlots
                      ? AppColors.primaryCta
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
        _pickFilterChips(all),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: const Color(0xFF3C1E1E),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _sendPicksToFriend,
              icon: const Icon(Icons.chat_bubble, size: 16),
              label: const Text(
                '카톡으로 친구에게 후보 보내기',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    '지금 영업 중인 매장이 없어요.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final on = _picked.contains(r.id);
                    return GestureDetector(
                      onTap: () {
                        if (!on && _picked.length >= rouletteMaxSlots) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('최대 8곳까지 고를 수 있어요.'),
                            ),
                          );
                          return;
                        }
                        setState(() =>
                            on ? _picked.remove(r.id) : _picked.add(r.id));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: on ? const Color(0xFFE6F3EC) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: on
                                ? AppColors.primaryCta
                                : const Color(0xFFE5E7EB),
                            width: on ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${r.category} · ${r.area}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              on
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: on
                                  ? AppColors.primaryCta
                                  : const Color(0xFFD1D5DB),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 같이 고르기 목록 필터. 지금 영업 중인 매장이 있는 음식 종류만 보여준다.
  Widget _pickFilterChips(List<Restaurant> all) {
    final present = {for (final r in all) r.category};
    final cats = _cuisineList.where(present.contains).toList();
    if (cats.length < 2) return const SizedBox.shrink();
    return _chipRow([
      ('전체', _pickFilter.isEmpty, () => setState(_pickFilter.clear)),
      for (final c in cats)
        (
          c,
          _pickFilter.contains(c),
          () {
            setState(() {
              if (!_pickFilter.remove(c)) _pickFilter.add(c);
            });
          }
        ),
    ]);
  }

  void _buildPickWheel() {
    final byId = {for (final r in _all) r.id: r};
    final chosen = [
      for (final id in _picked)
        if (byId[id] != null) byId[id]!,
    ]..shuffle(_rng);
    setState(() {
      _pickWheel = chosen;
      _pickWheelStage = true;
      _winner = null;
    });
  }

  // ── 하단 고정 버튼 ──
  Widget _bottomBar() {
    final String label;
    final VoidCallback? onTap;
    if (_tab == 1 && !_pickWheelStage) {
      final ok = _picked.length >= rouletteMinSlots;
      label =
          ok ? '이 ${_picked.length}곳으로 룰렛 만들기' : '$rouletteMinSlots곳 이상 골라주세요';
      onTap = ok ? _buildPickWheel : null;
    } else {
      label = _winner == null ? '돌리기!' : '다시 돌리기';
      onTap = _canSpin ? _startSpin : null;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryCta,
            disabledBackgroundColor: const Color(0xFFE5E7EB),
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFF9CA3AF),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Text(
            _spinning ? '돌아가는 중…' : label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

/// 룰렛 판. 0번 칸은 화살표(맨 위)를 기준으로 시계 방향으로 놓이고 [rotation]만큼 돈다.
class _WheelPainter extends CustomPainter {
  final List<String> labels;
  final double rotation;
  final int? highlight;

  _WheelPainter({
    required this.labels,
    required this.rotation,
    required this.highlight,
  });

  static const _colors = [
    Color(0xFFE6F3EC),
    Color(0xFFFFF4CC),
    Color(0xFFDBEAFE),
    Color(0xFFFCE7F3),
    Color(0xFFEDE9FE),
    Color(0xFFFFE4D6),
    Color(0xFFD1FAE5),
    Color(0xFFFEF3C7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n == 0) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final sweep = 2 * math.pi / n;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * sweep + rotation;
      final isWinner = highlight == i;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color =
              isWinner ? const Color(0xFFBBF7D0) : _colors[i % _colors.length],
      );
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 14,
            fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * 0.66);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + sweep / 2);
      tp.paint(canvas, Offset(radius * 0.28, -tp.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF26BC7D));
    canvas.drawCircle(center, 16, Paint()..color = Colors.white);
    canvas.drawCircle(
        center,
        16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF26BC7D));
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rotation != rotation ||
      old.highlight != highlight ||
      old.labels.length != labels.length ||
      !_sameLabels(old.labels);

  bool _sameLabels(List<String> other) {
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] != other[i]) return false;
    }
    return true;
  }
}
