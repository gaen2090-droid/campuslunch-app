import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/korean_particle.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/my_page_section_row.dart';
import '../widgets/owner_restaurant_dropdown.dart';
import 'legal_policy_hub_screen.dart';
import 'owner_stats_screen.dart';
import 'settings_screen.dart';

/// 사장님 마이페이지: 매장 선택(드롭다운, 추가/삭제 포함) + 성장 도구 + 사장님 지원.
class OwnerMyScreen extends StatefulWidget {
  const OwnerMyScreen({super.key});

  @override
  State<OwnerMyScreen> createState() => _OwnerMyScreenState();
}

class _OwnerMyScreenState extends State<OwnerMyScreen> {
  String? _toast;
  String? _statsRestaurantId;
  int? _todayReports;
  int? _todayDetailViews;
  int? _todayMapClicks;

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _loadTodayStats(String restaurantId) async {
    _statsRestaurantId = restaurantId;
    final engagement = await context
        .read<AppProvider>()
        .fetchOwnerRestaurantEngagementStats(restaurantId);
    if (!mounted || _statsRestaurantId != restaurantId) return;
    setState(() {
      _todayReports = engagement['todayReports'];
      _todayDetailViews = engagement['todayDetailViews'];
      _todayMapClicks = engagement['todayMapClicks'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final ownerIds = provider.ownerRestaurantIds;
    final allRestaurants = provider.restaurants;

    final ownedList = ownerIds
        .map((rid) {
          try {
            return allRestaurants.firstWhere((r) => r.id.toString() == rid);
          } catch (_) {
            return null;
          }
        })
        .whereType<Restaurant>()
        .toList();

    final selectedId = provider.selectedOwnerRestaurantId;
    final restaurant = ownedList.isEmpty
        ? null
        : ownedList.firstWhere(
            (r) => r.id.toString() == selectedId,
            orElse: () => ownedList.first,
          );

    if (restaurant != null && _statsRestaurantId != restaurant.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTodayStats(restaurant.id);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        bottom: false,
        child: Stack(
        children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 매장 선택 헤더 (제보 탭과 완전히 동일한 공용 위젯) ──
              OwnerHeaderSection(
                ownedList: ownedList,
                selected: restaurant,
                onSettingsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),

              // ── "캠퍼스런치와 함께" 카드 ──
              if (restaurant != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCta,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${restaurant.name}${eunNeun(restaurant.name)} 오늘',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _InlineStat(
                                  label: '오늘 제보수',
                                  value: _todayReports == null ? '-' : '$_todayReports',
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InlineStat(
                                  label: '오늘 페이지 방문수',
                                  value: _todayDetailViews == null ? '-' : '$_todayDetailViews',
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InlineStat(
                                  label: '오늘 지도 클릭수',
                                  value: _todayMapClicks == null ? '-' : '$_todayMapClicks',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // ══ 성장 도구 ══
              _OwnerCardSection(
                title: '성장 도구',
                children: [
                  MyPageSectionRow(
                    label: '통계',
                    icon: const Icon(Icons.bar_chart_rounded,
                        size: 20, color: Color(0xFF000000)),
                    onTap: restaurant == null
                        ? () {}
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OwnerStatsScreen(restaurant: restaurant),
                              ),
                            ),
                  ),
                  MyPageSectionRow(
                    label: '홍보',
                    icon: const Icon(Icons.campaign_outlined,
                        size: 20, color: Color(0xFF000000)),
                    showBottomBorder: false,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '예정',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    onTap: () => _showToast('준비 중이에요. 곧 만나요!'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ══ 사장님 지원 ══
              _OwnerCardSection(
                title: '사장님 지원',
                children: [
                  MyPageSectionRow(
                    label: '사장님 이용 가이드',
                    icon: const Icon(Icons.help_rounded,
                        size: 20, color: Color(0xFF000000)),
                    onTap: () => _showToast('준비 중이에요. 곧 만나요!'),
                  ),
                  MyPageSectionRow(
                    label: '개선 제안',
                    icon: const Icon(Icons.lightbulb_outline,
                        size: 20, color: Color(0xFF000000)),
                    onTap: () => showFeedbackSheet(context),
                  ),
                  MyPageSectionRow(
                    label: '약관 및 정책',
                    icon: const Icon(Icons.description_outlined,
                        size: 20, color: Color(0xFF000000)),
                    showBottomBorder: false,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LegalPolicyHubScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_toast != null)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryCta,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _toast!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
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

/// 리스트가 아닌 카드 형태로 감싼 마이페이지 섹션 (레퍼런스: 배달앱 사장님 메뉴 화면).
/// 섹션 제목도 카드 바깥이 아니라 카드 맨 위에 포함된다.
class _OwnerCardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _OwnerCardSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF000000),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// "캠퍼스런치와 함께" 카드 내부의 세로 구분선으로 나뉜 지표 한 칸
class _InlineStat extends StatelessWidget {
  final String label;
  final String value;

  const _InlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
