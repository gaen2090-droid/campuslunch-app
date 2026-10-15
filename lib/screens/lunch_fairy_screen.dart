import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart'
    show Button, Link, ShareClient, TextTemplate;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/lunch_fairy_flavor.dart';
import '../utils/lunch_fairy_recommender.dart';
import '../widgets/share_sheet.dart' show buildShareLink;
import '../widgets/restaurant_image.dart';
import 'detail_screen.dart';

/// 홈 11~14시 배너. 평일 점심시간에만 노출한다 (판정은 [isFairyBannerTime]).
class LunchFairyBanner extends StatelessWidget {
  final VoidCallback onTap;

  /// 마이 탭처럼 다른 카드와 나란히 놓일 때: 회색 테두리를 두르고 부제를 뺀다.
  final bool compact;
  const LunchFairyBanner(
      {super.key, required this.onTap, this.compact = false});

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

  /// 음식 종류를 고른 뒤 요정이 하는 말.
  static const _cuisineReactions = <String, String>{
    '한식': '한식 좋죠! 따끈한 국밥 먹고싶당 ( ›´-`‹ )',
    '중식': '중식 좋죠! 짜장면 먹고싶당 ( ›´-`‹ )',
    '일식': '일식 좋죠! 돈카츠 먹고싶당 ( ›´-`‹ )',
    '양식': '양식 좋죠! 파스타 먹고싶당 ( ›´-`‹ )',
    '분식': '분식 좋죠! 떡볶이 먹고싶당 ( ›´-`‹ )',
    '아시아': '아시아 음식 좋죠! 쌀국수 먹고싶당 ( ›´-`‹ )',
  };
  static const _budgets = <(String, int?)>[
    ('~8천', 8000),
    ('~1만', 10000),
    ('~1만3천', 13000),
    ('상관없음', null),
  ];
  String? _cuisine;
  int? _budget;
  int? _walk;

  /// 흑석(=정문+중문) / 상도(=후문). 복수 선택 가능하고, 도보 조건과 함께 쓸 수 있다.
  /// 값은 매장의 area 그대로(정문·중문·후문)이다.
  final Set<String> _areas = {};

  static const _heukseokAreas = ['정문', '중문'];
  static const _sangdoAreas = ['후문'];

  /// 질문은 한 화면에 하나씩: 0 동행 → 1 음식종류 → 2 예산 → 3 위치.
  static const _lastStep = 3;
  int _step = 0;

  /// 저장된 지난 답변이 있으면 첫 화면에 "지난번처럼" 버튼을 보여준다.
  bool _hasSaved = false;

  /// 저장돼 있던 지난 답변의 스냅샷. 화면에서 선택을 바꿔도 변하지 않는다.
  ({
    FairyCompanion companion,
    String? cuisine,
    int? budget,
    int? walk,
    Set<String> areas,
    String summary,
  })? _savedAnswers;
  FairyCompanion _companion = FairyCompanion.solo;

  /// 앱 위치 모드 ON + OS 권한 허용일 때만 거리 질문을 고를 수 있다.
  bool _locationReady = false;
  _Phase _phase = _Phase.questions;
  FairyPick? _pick;
  FairyRequest? _lastRequest;
  FairyPosition? _lastPosition;
  final Set<String> _seen = {};
  final math.Random _random = math.Random();

  /// 결과 말투를 고르는 값. 추천이 새로 나올 때마다 바뀌고, 화면이 다시 그려져도 유지된다.
  int _flavorSeed = 0;

  /// "고르는 중" 연출(카드 섞기)을 보여주는 최소 시간.
  static const _minThinking = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _track('open');
    _restoreAnswers();
    _checkLocation();
  }

  /// 어드민 운영 지표용 사용 기록. 실패해도 화면에는 영향이 없다.
  void _track(String action) {
    unawaited(context.read<AppProvider>().recordFeatureEvent('fairy', action));
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
          ..addAll(
              savedAreas.where((a) => a == '정문' || a == '중문' || a == '후문'));
        // 흑석은 정문+중문을 함께 다룬다. 예전에 정문만 저장된 값도 흑석 전체로 맞춘다.
        if (_areas.contains('정문') || _areas.contains('중문')) {
          _areas.addAll(_heukseokAreas);
        }
        _hasSaved = prefs.containsKey(_kCompanion);
        final saved = prefs.getString(_kCompanion);
        _companion = FairyCompanion.values.firstWhere(
          (c) => c.name == saved,
          // 예전 버전(혼밥/친구랑 bool) 답변도 이어받는다.
          orElse: () => (prefs.getBool(_kFriend) ?? false)
              ? FairyCompanion.friend
              : FairyCompanion.solo,
        );
        if (_hasSaved) _snapshotAnswers();
      });
    } catch (_) {
      // 저장된 답변이 없어도 기본값(상관없음/혼밥)으로 동작한다.
    }
  }

  /// 지금 답변을 "지난번" 답변으로 기억한다. 추천을 실행할 때마다 갱신된다.
  void _snapshotAnswers() {
    _savedAnswers = (
      companion: _companion,
      cuisine: _cuisine,
      budget: _budget,
      walk: _walk,
      areas: _areas.toSet(),
      summary: _savedSummary,
    );
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

  /// "가까운 곳"(도보 10분). 위치가 꺼져 있으면 OS 위치 권한 팝업을 띄우고, 허용되면 선택한다.
  /// 이미 "다시 묻지 않음"으로 거부해 OS가 팝업을 더 띄울 수 없으면 설정 이동을 안내한다.
  Future<void> _chooseNear() async {
    if (!_locationReady) {
      await _enableLocation();
      if (!mounted) return;
      if (!_locationReady) {
        await _showLocationDeniedDialog();
        return;
      }
    }
    _answer(() {
      _walk = 10;
      _areas.clear();
    });
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
    final startedAt = DateTime.now();
    setState(() => _phase = _Phase.thinking);
    _seen.clear();
    _snapshotAnswers();
    await _saveAnswers();

    // 사장님이 방금 고친 메뉴·영업시간·혼잡도가 바로 반영되도록 매번 최신 데이터로 계산한다.
    // 갱신에 실패해도 가지고 있는 목록으로 계속 진행한다.
    // 목록만 받고(푸시 동기화 등은 기다리지 않음) 시간 제한을 둔다. 느리거나 실패해도
    // 가지고 있는 목록으로 계속 진행한다.
    try {
      await provider
          .reloadRestaurantsOnly()
          .timeout(const Duration(seconds: 8));
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
    // 계산이 금방 끝나도 카드 섞기 연출을 짧게라도 보여준다.
    final remain = _minThinking - DateTime.now().difference(startedAt);
    if (remain > Duration.zero) await Future<void>.delayed(remain);
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
        _flavorSeed = _random.nextInt(1 << 20);
        _seen.add(outcome.pick!.restaurant.id);
        _phase = _Phase.result;
        _track('result_shown');
      } else {
        _pick = null;
        _phase = outcome.nothingOpen ? _Phase.nothingOpen : _Phase.exhausted;
      }
    });
  }

  Future<void> _reroll() async {
    _track('reroll');
    setState(() => _phase = _Phase.thinking);
    await Future<void>.delayed(_minThinking);
    if (!mounted) return;
    _recommend();
  }

  void _restartQuestions() => setState(() {
        _step = 0;
        _phase = _Phase.questions;
      });

  /// 결과를 카카오톡으로 공유한다. 카카오톡을 쓸 수 없으면 기본 공유창으로 넘어간다.
  /// 혼잡도는 시간이 지나면 달라지므로 문구에 넣지 않는다.
  Future<void> _shareResult(FairyPick pick) async {
    _track('share_click');
    final r = pick.restaurant;
    final menus = fairySignatureMenus(r).map((m) => m.name).toList();
    final menuLine = menus.isNotEmpty
        ? '\n대표메뉴: ${menus.join(' · ')}'
        : (pick.menu != null ? '\n추천메뉴: ${pick.menu!.name}' : '');
    final text = '오늘 점심, 점메추 요정의 선택은 ${r.name}!'
        '$menuLine\n캠퍼스런치에서 점메추 요정에게 맡겨보세요.';

    final url = Uri.parse(buildShareLink(r));
    final params = r.linkNo > 0
        ? <String, String>{'r': '${r.linkNo}'}
        : <String, String>{'path': 'home'};
    final link = Link(
      webUrl: url,
      mobileWebUrl: url,
      androidExecutionParams: params,
      iosExecutionParams: params,
    );
    final template = TextTemplate(
      text: text,
      link: link,
      buttons: [Button(title: '앱에서 열기', link: link)],
    );

    try {
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
        return;
      }
      await Share.share('$text\n${buildShareLink(r)}');
    } catch (e) {
      debugPrint('[Fairy] share failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유를 열지 못했어요. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  void _openDetail(Restaurant r) {
    _track('detail_click');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기한 매장 화면과 같은 AppBar 구성: 뒤로가기 IconButton(18) + titleSpacing 0 +
    // 제목 Pretendard 18 / w700 / letterSpacing -0.5, 왼쪽 정렬.
    final inSteps = _phase == _Phase.questions && _step > 0;
    return PopScope(
        canPop: !inSteps,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && inSteps) setState(() => _step--);
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
                if (inSteps) {
                  setState(() => _step--);
                } else {
                  Navigator.pop(context);
                }
              },
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
        ));
  }

  // ── 질문 (한 화면에 하나씩) ──

  /// 선택만 반영한다. 다음 질문으로는 아래 "다음" 버튼으로 넘어간다.
  void _answer(VoidCallback apply) => setState(apply);

  void _next() {
    if (_step >= _lastStep) {
      _start();
    } else {
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) setState(() => _step--);
  }

  /// 위치 질문의 현재 선택: 'any' | 'heukseok' | 'sangdo' | 'near'.
  String get _locationChoice {
    if (_walk != null) return 'near';
    final h = _areas.containsAll(_heukseokAreas);
    final s = _areas.containsAll(_sangdoAreas);
    if (h && !s) return 'heukseok';
    if (s && !h) return 'sangdo';
    return 'any';
  }

  String _companionLabel(FairyCompanion c) => switch (c) {
        FairyCompanion.solo => '혼밥',
        FairyCompanion.friend => '친구랑',
        FairyCompanion.date => '밥약',
      };

  String _budgetLabel() =>
      _budgets.firstWhere((b) => b.$2 == _budget, orElse: () => ('', null)).$1;

  String get _savedSummary => [
        _companionLabel(_companion),
        _cuisine ?? '음식 상관없음',
        _budget == null ? '예산 상관없음' : _budgetLabel(),
        switch (_locationChoice) {
          'near' => '가까운 곳',
          'heukseok' => '흑석',
          'sangdo' => '상도',
          _ => '위치 상관없음',
        },
      ].join(' · ');

  Widget _buildQuestions() {
    final (reaction, question) = switch (_step) {
      0 => ('오늘 점심 메뉴는 저에게 맡겨주세요 (・ω<)', '오늘 누구랑 드세요?'),
      1 => (
          switch (_companion) {
            FairyCompanion.solo => '혼밥이시군요! 편한 곳으로 찾아볼게요.',
            FairyCompanion.friend => '함께 먹는 점심이 제일 즐겁죠!',
            FairyCompanion.date => '밥약이군요, 제대로 골라볼게요!',
          },
          '뭐가 땡기세요?'
        ),
      2 => (
          _cuisine == null
              ? '다 좋다니, 폭넓게 볼게요!'
              : (_cuisineReactions[_cuisine] ?? '$_cuisine 좋죠!'),
          '1인당 예산은 어느 정도예요?'
        ),
      _ => (
          _budget == null
              ? '예산 걱정 없는 날이군요! 〜(^∇^〜）'
              : '${_budgetLabel()} 안쪽으로 볼게요.',
          '어디서 드실래요?'
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepDots(current: _step, total: _lastStep + 1),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              // 기본 레이아웃은 내용을 세로 가운데에 놓으므로, 위쪽부터 채우도록 바꾼다.
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                alignment: Alignment.topCenter,
                children: [...previous, if (current != null) current],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(_kFairyAsset, width: 72, height: 72),
                        const SizedBox(width: 12),
                        // 말풍선: 왼쪽(요정 쪽)에 꼬리가 달린다.
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: -6,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Transform.rotate(
                                    angle: math.pi / 4,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F3EC),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F3EC),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                // 한 줄로 고정한다. 폭이 모자라는 기기에서는 글자가 잘리지 않고 조금 줄어든다.
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    reaction,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 14),
                    Text(
                      question,
                      style: const TextStyle(
                        fontFamily: 'OkDanDan',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // 마지막 질문에서만 조건을 넓혀 찾는다는 안내를 남긴다.
                      _step == _lastStep
                          ? '딱 맞는 곳이 없으면 조금씩 넓혀서 찾아줄게요.'
                          : '고민은 제가 할게요, 선택만 해주세요!',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._stepOptions(),
                    if (_step == _lastStep && !_locationReady) ...[
                      const SizedBox(height: 4),
                      _LocationHint(onEnable: _enableLocation),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_step == 0 && _savedAnswers != null) ...[
            const SizedBox(height: 8),
            _repeatButton(),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (_step > 0) ...[
                SizedBox(
                  width: 96,
                  height: 58,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _prev,
                    child: const Text('이전',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCta,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _next,
                    child: Text(
                      _step >= _lastStep ? '골라주세요! 🪄' : '다음',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
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

  List<Widget> _stepOptions() {
    switch (_step) {
      case 0:
        return [
          _optionCard('혼밥', '혼자 조용히', _companion == FairyCompanion.solo,
              () => _answer(() => _companion = FairyCompanion.solo)),
          _optionCard('친구랑', '같이 왁자지껄', _companion == FairyCompanion.friend,
              () => _answer(() => _companion = FairyCompanion.friend)),
          _optionCard('밥약', '약속 잡고 제대로', _companion == FairyCompanion.date,
              () => _answer(() => _companion = FairyCompanion.date)),
        ];
      case 1:
        return [
          _optionGrid([
            ('상관없음', _cuisine == null, () => _answer(() => _cuisine = null)),
            for (final c in _cuisines)
              (c, _cuisine == c, () => _answer(() => _cuisine = c)),
          ]),
        ];
      case 2:
        return [
          _optionGrid([
            for (final (label, value) in _budgets)
              (label, _budget == value, () => _answer(() => _budget = value)),
          ]),
        ];
      default:
        final choice = _locationChoice;
        return [
          _optionCard(
              '상관없음',
              '어디든 좋아요',
              choice == 'any',
              () => _answer(() {
                    _walk = null;
                    _areas.clear();
                  })),
          _optionCard(
              '흑석',
              '정문 근처에서 먹고싶어요',
              choice == 'heukseok',
              () => _answer(() {
                    _walk = null;
                    _areas
                      ..clear()
                      ..addAll(_heukseokAreas);
                  })),
          _optionCard(
              '상도',
              '후문 근처에서 먹고싶어요',
              choice == 'sangdo',
              () => _answer(() {
                    _walk = null;
                    _areas
                      ..clear()
                      ..addAll(_sangdoAreas);
                  })),
          _optionCard(
              '가까운 곳', '내 위치에서 도보 10분 이내', choice == 'near', _chooseNear),
        ];
    }
  }

  Widget _optionCard(
      String label, String sub, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE6F3EC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primaryCta : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );
  }

  /// 선택지가 많은 질문(음식종류·예산)은 2열 카드.
  Widget _optionGrid(List<(String, bool, VoidCallback)> items) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, selected, onTap) in items)
              SizedBox(
                width: w,
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE6F3EC) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryCta
                            : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 지난번 답변 그대로 질문을 건너뛰고 바로 추천받는다.
  Widget _repeatButton() {
    return SizedBox(
      width: double.infinity,
      // 주 버튼(다음)과 헷갈리지 않게 회색 배경의 보조 버튼으로 둔다.
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFE5E7EB),
          foregroundColor: const Color(0xFF4B5563),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () {
          // 지금 화면에서 바꾼 선택이 아니라 저장돼 있던 지난 답변으로 추천한다.
          final saved = _savedAnswers;
          if (saved == null) return;
          setState(() {
            _companion = saved.companion;
            _cuisine = saved.cuisine;
            _budget = saved.budget;
            _walk = saved.walk;
            _areas
              ..clear()
              ..addAll(saved.areas);
          });
          _start();
        },
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 19),
                SizedBox(width: 6),
                Text(
                  '지난번처럼 바로 고르기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _savedAnswers?.summary ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
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
          _ShuffleCards(),
          SizedBox(height: 20),
          Text(
            '요정이 고르는 중이에요…',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
    final rarity = fairyRarity(pick);
    final timeNote = fairyTimeNote(pick, DateTime.now());

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          fairyHeadline(pick, _flavorSeed),
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, height: 1.35),
        ),
        if (timeNote != null) ...[
          const SizedBox(height: 6),
          Text(
            timeNote,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
        if (pick.relaxed.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _relaxedNote(pick.relaxed),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
        const SizedBox(height: 16),
        // 카드가 뒤집히며 결과가 공개된다. 탭하면 바로 공개, 같은 결과가 다시 그려져도 재생하지 않는다.
        _FlipReveal(
          key: ValueKey('${r.id}_$_flavorSeed'),
          onRevealed: () {
            if (rarity != FairyRarity.normal) HapticFeedback.mediumImpact();
          },
          front: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: rarity == FairyRarity.normal
                    ? const Color(0xFFE5E7EB)
                    : _rarityColor(rarity),
                width: rarity == FairyRarity.normal ? 1 : 2,
              ),
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
                      if (rarity != FairyRarity.normal) ...[
                        _rarityChip(rarity),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        r.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.area} · ${r.category}'
                        '${pick.walkMinutes != null ? ' · 걸어서 약 ${pick.walkMinutes}분' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                      if (showCrowd) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
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
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCta,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _reroll,
                child: const Text('다른 곳 볼래요',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _restartQuestions,
                child: const Text('조건 바꾸기',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );

    // 공유 버튼은 질문 화면의 하단 버튼처럼 맨 아래에 고정한다.
    return Column(
      children: [
        Expanded(child: list),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: const Color(0xFF3C1E1E),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _shareResult(pick),
              icon: const Icon(Icons.chat_bubble, size: 18),
              label: Text(
                // 혼밥이면 일반 공유, 친구랑·밥약이면 사달라고 조르는 문구.
                (_lastRequest?.companion ?? _companion) == FairyCompanion.solo
                    ? '카카오톡으로 공유하기'
                    : '친구에게 사달라고 조르기',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
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
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCta,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: _restartQuestions,
              child: const Text('조건 바꾸기'),
            ),
          ],
        ),
      ),
    );
  }

  // 말투(헤드라인·시간대 멘트·희귀도 문구)는 lunch_fairy_flavor.dart 에서 만든다.
  // 엔진은 이유 코드만 돌려준다.

  Color _rarityColor(FairyRarity rarity) => rarity == FairyRarity.epic
      ? const Color(0xFF7C3AED)
      : const Color(0xFF2563EB);

  Widget _rarityChip(FairyRarity rarity) {
    final color = _rarityColor(rarity);
    final bg = rarity == FairyRarity.epic
        ? const Color(0xFFEDE9FE)
        : const Color(0xFFDBEAFE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${fairyRarityLabel(rarity)} · ${fairyRarityReason(rarity)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
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
    return '딱 맞는 곳이 없어서 ${parts.join('·')} 조건을 조금 넓혀봤어요!';
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

/// 카드 뒷면 (섞이는 연출과 뒤집기 직전 모습이 같다).
Widget _fairyCardBack({double width = 96, double height = 128}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE6F3EC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFCDE9DC), width: 2),
    ),
    child: Center(
      child:
          Image.asset(_kFairyAsset, width: width * 0.55, height: width * 0.55),
    ),
  );
}

/// "고르는 중" — 카드 세 장이 좌우로 섞인다. 모션 줄이기 설정이면 정지 상태로 보여준다.
class _ShuffleCards extends StatefulWidget {
  const _ShuffleCards();

  @override
  State<_ShuffleCards> createState() => _ShuffleCardsState();
}

class _ShuffleCardsState extends State<_ShuffleCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: 240,
      height: 150,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                () {
                  final phase = reduce ? i / 3 : (_c.value + i / 3) % 1.0;
                  final dx = math.sin(phase * 2 * math.pi) * 62;
                  final tilt = math.cos(phase * 2 * math.pi) * 0.18;
                  // 가운데를 지날 때(dx≈0) 위로 올라와 서로 겹쳐 섞이는 느낌을 준다.
                  final lift = -math.cos(phase * 2 * math.pi).abs() * 8;
                  return Transform.translate(
                    offset: Offset(dx, lift),
                    child:
                        Transform.rotate(angle: tilt, child: _fairyCardBack()),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

/// 결과 카드를 뒷면에서 앞면으로 뒤집으며 공개한다. 탭하면 즉시 공개한다.
class _FlipReveal extends StatefulWidget {
  final Widget front;
  final VoidCallback? onRevealed;
  const _FlipReveal({super.key, required this.front, this.onRevealed});

  @override
  State<_FlipReveal> createState() => _FlipRevealState();
}

class _FlipRevealState extends State<_FlipReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _notifyRevealed();
    });
    _c.forward();
  }

  void _notifyRevealed() {
    if (_notified || !mounted) return;
    _notified = true;
    widget.onRevealed?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 모션 줄이기 설정이면 뒤집지 않고 바로 보여준다.
    if (MediaQuery.of(context).disableAnimations && _c.value < 1) {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_c.isAnimating) _c.value = 1;
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final angle = Curves.easeInOut.transform(_c.value) * math.pi;
          final showFront = angle > math.pi / 2;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: showFront
                // 앞면은 이미 반 바퀴 돌아간 상태라 거울상이 되므로 한 번 더 뒤집어 바로 세운다.
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.front,
                  )
                // 뒷면: 앞면과 같은 크기를 유지하려고 투명한 앞면 위에 뒷면 장식을 얹는다.
                : Stack(
                    children: [
                      Opacity(opacity: 0, child: widget.front),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F3EC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFCDE9DC), width: 2),
                          ),
                          child: Center(
                            child: Image.asset(_kFairyAsset,
                                width: 72, height: 72),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// 질문 진행 점.
class _StepDots extends StatelessWidget {
  final int current;
  final int total;
  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            margin: const EdgeInsets.only(right: 6),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color:
                  i <= current ? AppColors.primaryCta : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
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
