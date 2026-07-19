import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/coach_mark_step.dart';
import '../providers/app_provider.dart';
import '../widgets/coach_mark_overlay.dart';
import '../constants/app_links.dart';
import 'community_screen.dart';
import 'coupon_box_screen.dart';
import 'detail_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'my_screen.dart';
import 'owner_screen.dart';

/// 지도 탭 아이콘 코치마크가 위치를 찾을 수 있도록 전역으로 노출
final mapNavIconKey = GlobalKey();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _mapMounted = false;
  bool _communityMounted = false;
  bool _showCoachMark = false;
  bool _handlingAppLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().recordAppSession();
      final provider = context.read<AppProvider>();
      if (provider.showSignupCompleteMessage) {
        provider.clearSignupCompleteMessage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '회원가입이 완료되었어요! 환영합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            backgroundColor: const Color(0xFF9ECA8B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _handlePendingAppLink();
      _maybeShowCoachMark();
    });
  }

  Future<void> _handlePendingAppLink() async {
    if (_handlingAppLink || !mounted) return;
    final provider = context.read<AppProvider>();
    if (!provider.hasPendingAppLink) return;

    _handlingAppLink = true;
    final pending = provider.consumePendingAppLink();
    if (pending == null) {
      _handlingAppLink = false;
      return;
    }

    try {
      switch (pending.target) {
        case AppLinkTarget.home:
          provider.setMainTabIndex(provider.homeTabIndex);
        case AppLinkTarget.coupons:
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CouponBoxScreen()),
          );
        case AppLinkTarget.restaurant:
          final linkNo = pending.linkNo;
          if (linkNo == null || linkNo <= 0) return;
          final restaurant =
              await provider.fetchRestaurantByLinkNo(linkNo);
          if (!mounted || restaurant == null) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailScreen(restaurant: restaurant),
            ),
          );
      }
    } finally {
      _handlingAppLink = false;
    }
  }

  Future<void> _maybeShowCoachMark() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final show = await provider.shouldShowCoachMark();
    if (!mounted || !show) return;
    setState(() => _showCoachMark = true);
  }

  void _finishCoachMark() {
    context.read<AppProvider>().completeCoachMark();
    setState(() => _showCoachMark = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (provider.hasPendingAppLink && !_handlingAppLink) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handlePendingAppLink();
      });
    }
    if (provider.pendingCommunityPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = context.read<AppProvider>();
        p.setMainTabIndex(p.communityTabIndex);
      });
    }
    final hasOwner = provider.hasOwnerTab;
    final index = provider.mainTabIndex.clamp(0, hasOwner ? 4 : 3);
    final mapIndex = hasOwner ? 2 : 1;
    final communityIndex = hasOwner ? 3 : 2;

    if (index == mapIndex) {
      _mapMounted = true;
    }
    if (index == communityIndex) {
      _communityMounted = true;
    }

    final nonMapTabs = <Widget>[
      if (hasOwner) const OwnerScreen(),
      const HomeScreen(),
      if (_communityMounted) const CommunityScreen() else const SizedBox.shrink(),
      const MyScreen(),
    ];
    final nonMapIndex =
        index == mapIndex ? 0 : (index > mapIndex ? index - 1 : index);

    // PlatformView(카카오맵)는 IndexedStack 비활성 자식에 두면 iOS 터치가 막힘
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          // 지도 탭 안 검색창 키보드가 뜨고 닫힐 때, 이 바깥쪽 Scaffold가
          // body 크기를 먼저 줄여버려서(중첩 Scaffold라 지도 화면 안쪽에 걸어둔
          // resizeToAvoidBottomInset:false는 이미 늦음) 그 안의 지도
          // PlatformView까지 리사이즈되는 버그가 있었다. 지도 탭일 때만 이
          // 바깥 Scaffold의 키보드 회피를 꺼서 body(지도) 크기를 고정한다 —
          // 다른 탭(홈 검색창 등)은 기존처럼 키보드 회피 유지.
          resizeToAvoidBottomInset: index != mapIndex,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (index != mapIndex)
                IndexedStack(index: nonMapIndex, children: nonMapTabs),
              if (_mapMounted && index == mapIndex)
                const MapScreen(key: ValueKey('main_map_tab')),
            ],
          ),
          bottomNavigationBar: _BottomNav(
            hasOwnerTab: hasOwner,
            current: index,
            mapIndex: mapIndex,
            onTap: (i) => provider.setMainTabIndex(i),
          ),
        ),
        // bottomNavigationBar(지도 탭 아이콘)까지 덮으려면 Scaffold 밖, 화면 전체를
        // 덮는 최상위 Stack에 있어야 한다. Scaffold.body 안에 두면 nav bar 영역은
        // 가려지지 않아 4번째 스텝(지도 아이콘)이 화면에 그려지지 않는다.
        if (_showCoachMark && index != mapIndex)
          Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                CoachMarkOverlay(
                  steps: [
                    CoachMarkStep(
                      targetKeys: [HomeScreen.filterRowKey],
                      title: '원하는 조건으로 걸러봐요',
                      subtitle: '내가 원하는 조건의 매장을 찾을 수 있어요',
                    ),
                    CoachMarkStep(
                      targetKeys: [HomeScreen.availableBadgeKey],
                      title: '혼잡도를 한눈에 확인',
                      subtitle: '바로 입장 가능한 매장을 확인해보세요',
                    ),
                    // 추천 배너(Hero) 제외, 화면에 실제로 존재하는 첫 카드를 섹션 순서대로 후보에 넣는다.
                    // 대상이 스크롤 뷰포트 밖이어도 CoachMarkOverlay가 자동 스크롤 후 가리킨다.
                    CoachMarkStep(
                      targetKeys: [
                        HomeScreen.firstAvailableCardKey,
                        HomeScreen.firstSlightlyBusyCardKey,
                        HomeScreen.stampCardKey,
                        HomeScreen.firstBusyCardKey,
                      ],
                      title: '제보하고 스탬프 적립',
                      subtitle: '카드를 눌러 제보하면 스탬프를 받아요. 모으면 커피 쿠폰으로 교환해요',
                    ),
                    CoachMarkStep(
                      targetKeys: [mapNavIconKey],
                      title: '지도로도 볼 수 있어요',
                      subtitle: '내 주변 매장을 지도에서 한눈에',
                    ),
                  ],
                  onFinish: _finishCoachMark,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final bool hasOwnerTab;
  final int current;
  final int mapIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.hasOwnerTab,
    required this.current,
    required this.mapIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = hasOwnerTab
        ? const [
            _NavItem(
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront,
              label: '사장님',
            ),
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: '홈',
            ),
            _NavItem(
              icon: Icons.map_outlined,
              activeIcon: Icons.map,
              label: '지도',
            ),
            _NavItem(
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum,
              label: '커뮤니티',
            ),
            _NavItem(
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle_outlined,
              label: 'MY',
            ),
          ]
        : const [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: '홈',
            ),
            _NavItem(
              icon: Icons.map_outlined,
              activeIcon: Icons.map,
              label: '지도',
            ),
            _NavItem(
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum,
              label: '커뮤니티',
            ),
            _NavItem(
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle_outlined,
              label: 'MY',
            ),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                _NavTab(
                  index: i,
                  current: current,
                  item: items[i],
                  onTap: onTap,
                  iconKey: i == mapIndex ? mapNavIconKey : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavTab extends StatelessWidget {
  final int index;
  final int current;
  final _NavItem item;
  final ValueChanged<int> onTap;
  final Key? iconKey;

  const _NavTab({
    required this.index,
    required this.current,
    required this.item,
    required this.onTap,
    this.iconKey,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              key: iconKey,
              width: 22,
              height: 22,
              child: Icon(
                active ? item.activeIcon : item.icon,
                size: 22,
                color: active ? const Color(0xFF5E8C4A) : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    active ? const Color(0xFF5E8C4A) : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
