import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'my_screen.dart';
import 'owner_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().recordAppSession();
      final provider = context.read<AppProvider>();
      if (!provider.showSignupCompleteMessage) return;
      provider.clearSignupCompleteMessage();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '회원가입이 완료되었어요! 환영합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF111827),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hasOwner = provider.hasOwnerTab;
    final index = provider.mainTabIndex.clamp(0, hasOwner ? 3 : 2);

    final tabs = hasOwner
        ? const [
            OwnerScreen(),
            HomeScreen(),
            MapScreen(),
            MyScreen(),
          ]
        : const [
            HomeScreen(),
            MapScreen(),
            MyScreen(),
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: IndexedStack(index: index, children: tabs),
      bottomNavigationBar: _BottomNav(
        hasOwnerTab: hasOwner,
        current: index,
        onTap: (i) => provider.setMainTabIndex(i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final bool hasOwnerTab;
  final int current;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.hasOwnerTab,
    required this.current,
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

  const _NavTab({
    required this.index,
    required this.current,
    required this.item,
    required this.onTap,
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
            Icon(
              active ? item.activeIcon : item.icon,
              size: 22,
              color: active ? const Color(0xFF1A1A1A) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    active ? const Color(0xFF1A1A1A) : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
