import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/owner_badge.dart';
import '../widgets/report_sheet.dart';

/// 가상 매장 — 실제 DB 매장이 아니라 미리보기 전용 고정값
const _demoRestaurantName = '중앙대피자맛집';

class _GuidePage {
  final String title;
  final String subtitle;
  final WidgetBuilder mockupBuilder;
  const _GuidePage({
    required this.title,
    required this.subtitle,
    required this.mockupBuilder,
  });
}

final _pages = [
  _GuidePage(
    title: '실시간으로\n매장 상태를 제보해요',
    subtitle: '바쁘면 매장 상태만 꾹 눌러주세요!\n입장 가능 인원수도 소비자 화면에 표시돼요',
    mockupBuilder: (_) => const _OwnerReportMockup(),
  ),
  _GuidePage(
    title: '커뮤니티에서\n소비자와 함께해요',
    subtitle: '사장님도 소비자와 똑같이 커뮤니티에서\n활동할 수 있어요. 글에는 사장님으로 표시돼요',
    mockupBuilder: (_) => const _OwnerCommunityMockup(),
  ),
  _GuidePage(
    title: '마이페이지에서\n매장 통계를 확인해요',
    subtitle: '제보수, 즐겨찾기수, 지도 클릭수 등\n매장 관련 통계를 한눈에 볼 수 있어요',
    mockupBuilder: (_) => const _OwnerStatsMockup(),
  ),
];

class OwnerUsageGuideScreen extends StatefulWidget {
  const OwnerUsageGuideScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OwnerUsageGuideScreen()),
    );
  }

  @override
  State<OwnerUsageGuideScreen> createState() => _OwnerUsageGuideScreenState();
}

class _OwnerUsageGuideScreenState extends State<OwnerUsageGuideScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<AppProvider>().completeOwnerUsageGuide();
    Navigator.of(context).pop();
  }

  void _goTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _goTo(_page + 1);
  }

  void _prev() {
    if (_page == 0) return;
    _goTo(_page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FBEE),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text(
                        '건너뛰기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PageView.builder(
                          controller: _controller,
                          itemCount: _pages.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (context, i) => _GuidePageView(page: _pages[i]),
                        ),
                        if (_page > 0)
                          Positioned(
                            left: -20,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _prev,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0x809CA3AF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_left,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!isLast)
                          Positioned(
                            right: -20,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _next,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0x809CA3AF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return GestureDetector(
                        onTap: () => _goTo(i),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: active ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF000000) : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isLast ? '시작하기' : '다음',
                          style: const TextStyle(
                            fontSize: 17,
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
          ),
        ],
      ),
    );
  }
}

class _GuidePageView extends StatelessWidget {
  final _GuidePage page;
  const _GuidePageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        page.mockupBuilder(context),
        const SizedBox(height: 28),
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF000000),
            height: 1.3,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          page.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// 모든 미리보기가 공유하는 카드 (usage_guide_screen.dart의 _PreviewCard와 동일 톤)
class _PreviewCard extends StatelessWidget {
  final Widget child;
  final double width;
  const _PreviewCard({required this.child, this.width = 280});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 48,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

/// 1페이지: 제보 탭 화면 미리보기 (owner_screen.dart 최신 UI 그대로 — 드롭다운 헤더 +
/// 소비자 화면 미리보기 배지 + 상태 카드 + 입장 인원 카드)
class _OwnerReportMockup extends StatelessWidget {
  const _OwnerReportMockup();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  _demoRestaurantName,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF000000),
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF000000)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '지금 매장 상태를 선택해주세요',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          for (final o in reportOptions.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: o.label == '여유로워요' ? o.bgColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: o.label == '여유로워요' ? o.borderColor : const Color(0xFFE5E7EB),
                    width: o.label == '여유로워요' ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: o.textColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          o.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: o.label == '여유로워요' ? o.textColor : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    if (o.label == '여유로워요')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: o.textColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '현재',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '지금 몇 명까지 입장 가능한가요?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '8',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
                      ),
                      Text(
                        ' 명',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2페이지: 커뮤니티 탭 화면 미리보기 — 헤더 + 자유게시판/맛집 컬렉션 탭 +
/// 사장님 배지가 붙은 최신 글이 맨 위에 있는 것처럼 구성
class _OwnerCommunityMockup extends StatelessWidget {
  const _OwnerCommunityMockup();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  '커뮤니티',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF000000),
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              Icon(Icons.search, color: Color(0xFF000000), size: 18),
              SizedBox(width: 10),
              Icon(Icons.notifications_outlined, color: Color(0xFF000000), size: 18),
              SizedBox(width: 10),
              Icon(Icons.menu, color: Color(0xFF000000), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MockSegmentTab(label: '자유게시판', active: true),
              _MockSegmentTab(label: '맛집 컬렉션', active: false),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Text(
                '$_demoRestaurantName 사장님',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
              ),
              SizedBox(width: 4),
              OwnerBadge(),
              SizedBox(width: 6),
              Text('방금 전', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '오늘 신메뉴 나왔어요! 많관부 🍕',
            style: TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.storefront_outlined, size: 13, color: Color(0xFF374151)),
                SizedBox(width: 4),
                Text(
                  _demoRestaurantName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Icon(Icons.favorite_border, size: 16, color: Color(0xFF9CA3AF)),
              SizedBox(width: 4),
              Text('12', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
              SizedBox(width: 14),
              Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF9CA3AF)),
              SizedBox(width: 4),
              Text('3', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockSegmentTab extends StatelessWidget {
  final String label;
  final bool active;
  const _MockSegmentTab({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF000000) : const Color(0xFFE5E7EB),
              width: active ? 2 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? const Color(0xFF000000) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

/// 3페이지: 사장님 통계 화면 미리보기 (owner_stats_screen.dart 톤 그대로, 가상 매장 값)
class _OwnerStatsMockup extends StatelessWidget {
  const _OwnerStatsMockup();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      width: 290,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.arrow_back_ios_new, size: 14, color: Color(0xFF000000)),
              SizedBox(width: 8),
              Text(
                '통계',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF000000)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF000000), Color(0xFF374151)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '캠퍼스런치 파트너',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70),
                ),
                SizedBox(height: 4),
                Text(
                  '$_demoRestaurantName은\n42일동안 함께하고 있어요',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, height: 1.3, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat(label: '오늘 제보수', value: '3건')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: '누적 즐겨찾기 수', value: '27명')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStat(label: '누적 지도 클릭 수', value: '154회')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: '누적 페이지 방문수', value: '312회')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
          ),
        ],
      ),
    );
  }
}
