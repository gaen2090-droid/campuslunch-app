import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/restaurants.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/crowd_status_label.dart';
import '../widgets/restaurant_image.dart';
import '../widgets/report_sheet.dart';
import '../widgets/rice_ball_icon.dart';

/// 사용법 가이드 1페이지 전용 — 항상 같은 매장 3곳을 고정으로 보여준다 (실데이터 사용 안 함)
final _previewRestaurants = initialRestaurants.take(3).toList();
/// 매장마다 다른 "n분 전" 표기를 보여주기 위한 고정 값 (3분 전 / 5분 전 / 방금 전)
const _previewUpdatedMinutes = [3, 5, 0];

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
    title: '실시간 혼잡도를\n한눈에 확인해요',
    subtitle: '중앙대 주변 매장의 혼잡도를 확인하고\n지금 바로 입장 가능한 곳을 찾아보세요',
    mockupBuilder: (context) => const _CrowdListMockup(),
  ),
  _GuidePage(
    title: '위치 기반으로\n혼잡도를 제보해요',
    subtitle: '매장 주변에서 혼잡도를 제보하면\n다른 학생들에게 큰 도움이 돼요',
    mockupBuilder: (_) => const _ReportMockup(),
  ),
  _GuidePage(
    title: '혼잡도를 제보하고\n커피 쿠폰을 받아요',
    subtitle: '스탬프를 20개 모으면\n커피 쿠폰을 받을 수 있어요',
    mockupBuilder: (_) => const _StampMockup(),
  ),
];

class UsageGuideScreen extends StatefulWidget {
  const UsageGuideScreen({super.key});

  @override
  State<UsageGuideScreen> createState() => _UsageGuideScreenState();
}

class _UsageGuideScreenState extends State<UsageGuideScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<AppProvider>().completeUsageGuide();
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

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            right: -80,
            top: 60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E6BA),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: 80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF9ECA8B).withAlpha(180),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
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
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => _GuidePageView(page: _pages[i]),
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
                              color: active ? const Color(0xFF5E8C4A) : const Color(0xFFE5E7EB),
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
                        color: const Color(0xFF9ECA8B),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFC8E6BA),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isLast ? '시작하기' : '다음',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
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
            color: Color(0xFF111827),
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

/// 모든 미리보기가 공유하는 카드 — 그림자 1개만, Stack/그라데이션/높이 제약 없음
class _PreviewCard extends StatelessWidget {
  final Widget child;
  final double width;
  const _PreviewCard({required this.child, this.width = 260});

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
            color: const Color(0xFF9ECA8B).withAlpha(60),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
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

/// 1페이지: 고정된 매장 3곳으로 홈 화면과 동일한 카드 디자인을 보여준다
/// (이름·구역·시간은 고정값, 이미지만 실제 DB에 등록된 같은 이름의 매장 사진을 사용)
class _CrowdListMockup extends StatelessWidget {
  const _CrowdListMockup();

  @override
  Widget build(BuildContext context) {
    final liveRestaurants = context.watch<AppProvider>().restaurants;
    String imageUrlFor(Restaurant seed) {
      final live = liveRestaurants.where((r) => r.name == seed.name).firstOrNull;
      return (live != null && live.imageUrl.isNotEmpty)
          ? live.imageUrl
          : seed.imageUrl;
    }

    return _PreviewCard(
      width: 290,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4C9C2A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '지금 바로 입장 가능',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _previewRestaurants.length; i++)
            _PreviewRestaurantRow(
              restaurant: _previewRestaurants[i],
              imageUrl: imageUrlFor(_previewRestaurants[i]),
              updatedMinutes: _previewUpdatedMinutes[i],
            ),
        ],
      ),
    );
  }
}

class _PreviewRestaurantRow extends StatelessWidget {
  final Restaurant restaurant;
  final String imageUrl;
  final int updatedMinutes;
  const _PreviewRestaurantRow({
    required this.restaurant,
    required this.imageUrl,
    required this.updatedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 36,
              height: 36,
              child: RestaurantImage(
                url: imageUrl,
                fallback: () => _InitialCircle(name: restaurant.name),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  restaurant.area == restaurant.category
                      ? restaurant.area
                      : '${restaurant.area} · ${restaurant.category}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDAFFCA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text.rich(
              TextSpan(
                text: '여유로움',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4C9C2A),
                ),
                children: [
                  TextSpan(
                    text: ' · ${formatUpdateAge(updatedMinutes)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
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

class _InitialCircle extends StatelessWidget {
  final String name;
  const _InitialCircle({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F8F0),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5E8C4A),
          ),
        ),
      ),
    );
  }
}

/// 2페이지: ReportSheet과 동일한 옵션/색/아이콘 토큰 (report_sheet.dart의 reportOptions 그대로 사용)
class _ReportMockup extends StatelessWidget {
  const _ReportMockup();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '지금 이 매장 상태가 어떤가요?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            initialRestaurants.first.name,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          ...reportOptions.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: o.bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: o.borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(o.icon, size: 16, color: o.textColor),
                      const SizedBox(width: 8),
                      Text(
                        o.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: o.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

/// 3페이지: reward_screen.dart의 스탬프 현황 카드 + _StampCell과 동일한 토큰
class _StampMockup extends StatelessWidget {
  const _StampMockup();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '14',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF5E8C4A), height: 1),
              ),
              Text(
                ' / 20',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 14 / 20,
              minHeight: 6,
              backgroundColor: Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(Color(0xFF5E8C4A)),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '아메리카노 쿠폰까지 6개 남았어요',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: 20,
            itemBuilder: (_, i) => _StampCell(filled: i < 14),
          ),
        ],
      ),
    );
  }
}

/// reward_screen.dart의 _StampCell과 동일한 토큰
class _StampCell extends StatelessWidget {
  final bool filled;
  const _StampCell({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFE8F5E1) : const Color(0xFFF9FAFB),
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? const Color(0xFFBFE0B0) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Center(
        child: filled
            ? const RiceBallIcon(size: 18)
            : const Opacity(
                opacity: 0.35,
                child: RiceBallIcon(size: 18),
              ),
      ),
    );
  }
}
