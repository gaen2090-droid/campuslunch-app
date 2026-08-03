import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/my_page_section_row.dart';
import '../widgets/owner_verify_sheet.dart';
import '../widgets/rice_ball_icon.dart';
import 'bookmark_list_screen.dart';
import 'coupon_box_screen.dart';
import 'legal_policy_hub_screen.dart';
import 'referral_invite_screen.dart';
import 'reward_screen.dart';
import 'settings_screen.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  bool _showEditSheet = false;
  String _editNickname = '';
  final _nicknameCtrl = TextEditingController();

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _openEdit(String current) {
    _nicknameCtrl.value = TextEditingValue(
      text: current,
      selection: TextSelection.collapsed(offset: current.length),
    );
    setState(() {
      _editNickname = current;
      _showEditSheet = true;
    });
  }

  Future<void> _saveNickname() async {
    final trimmed = _editNickname.trim();
    if (trimmed.isEmpty) {
      setState(() => _showEditSheet = false);
      return;
    }
    final err = await context.read<AppProvider>().updateNickname(trimmed);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    setState(() => _showEditSheet = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hasOwner = provider.hasOwnerTab;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 페이지 타이틀 ──
              Padding(
                // IconButton의 접근성 최소 탭 영역(48x48)은 그대로 두고, 그
                // 내장 여백만큼 우측 마진을 줄여 시각적으로 화면 끝(커뮤니티
                // 헤더 아이콘과 동일 위치)에 가깝게 붙인다.
                padding: const EdgeInsets.fromLTRB(20, 0, 14, 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '마이페이지',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF000000),
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_outlined,
                          size: 24, color: Color(0xFF000000)),
                    ),
                  ],
                ),
              ),

              // ══ 카드 1: 프로필 + 오늘의 스탬프 + 바로가기 3버튼 ══
              _MyCardSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 프로필 ──
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openEdit(provider.nickname),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                                color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                            child: const Center(
                                child: Icon(Icons.person,
                                    size: 22, color: Color(0xFF9CA3AF))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              provider.nickname.isEmpty
                                  ? '앙대 학생'
                                  : provider.nickname,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF000000)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text('닉네임 수정',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF6B7280))),
                          const SizedBox(width: 5),
                          const Icon(Icons.arrow_forward_ios,
                              size: 9, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                        ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 21),

                    // ── 오늘의 스탬프 (초록 키컬러 카드) ──
                    _RewardCard(
                      reward: provider.reward,
                      loadFailed: provider.rewardLoadFailed,
                      onRetry: () => provider.fetchMyReward(),
                    ),

                    const SizedBox(height: 12),

                    // ── 즐겨찾기 / 스탬프북 / 내 쿠폰함 ──
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.bookmark,
                            label: '즐겨찾기',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BookmarkListScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.menu_book_rounded,
                            label: '스탬프북',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RewardScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.card_giftcard_rounded,
                            label: '내 쿠폰함',
                            showDot: provider.hasUnseenCoupon,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CouponBoxScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ══ 카드 2: 쿠폰/이벤트 ══
              _MyCardSection(
                title: '이벤트',
                child: Column(
                  children: [
                    MyPageSectionRow(
                      label: '친구 초대하고 함께 스탬프 받기',
                      icon: const Icon(Icons.card_giftcard_outlined,
                          size: 20, color: Color(0xFF000000)),
                      showBottomBorder: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReferralInviteScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ══ 카드 3: 고객지원 ══
              _MyCardSection(
                title: '고객지원',
                child: Column(
                  children: [
                    MyPageSectionRow(
                      label: '캠퍼스런치 이용 가이드',
                      icon: const Icon(Icons.help_rounded,
                          size: 20, color: Color(0xFF000000)),
                      onTap: () => launchUrl(
                        Uri.parse(
                            'https://sheer-parent-7ed.notion.site/385c273f6bec80eda925df4945c021b7?source=copy_link'),
                        mode: LaunchMode.externalApplication,
                      ),
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
                        MaterialPageRoute(
                            builder: (_) =>
                                const LegalPolicyHubScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              // ══ 카드 4: 비즈니스 ══
              if (!hasOwner) ...[
                const SizedBox(height: 16),
                _MyCardSection(
                  title: '비즈니스',
                  child: Column(
                    children: [
                      MyPageSectionRow(
                        label: '내 가게 등록',
                        icon: const Icon(Icons.storefront_outlined,
                            size: 20, color: Color(0xFF000000)),
                        showBottomBorder: false,
                        onTap: () => OwnerVerifyScreen.show(context),
                      ),
                    ],
                  ),
                ),
              ],

              // ── 사장님(오너) 전용 배너 ──
              if (hasOwner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: GestureDetector(
                    onTap: () => provider.setMainTabIndex(0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Center(
                        child: Text(
                          '내 매장 혼잡도 관리',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── 닉네임 수정 시트 ──
        if (_showEditSheet)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showEditSheet = false),
              child: Container(
                color: Colors.black.withAlpha(76),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {}, // absorb taps
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        padding: EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            MediaQuery.of(context).padding.bottom +
                                MediaQuery.of(context).viewInsets.bottom +
                                24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '닉네임 수정',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF000000)),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      autofocus: true,
                                      controller: _nicknameCtrl,
                                      onChanged: (v) {
                                        if (v.length > 20) {
                                          _nicknameCtrl.value =
                                              TextEditingValue(
                                            text: v.substring(0, 20),
                                            selection:
                                                const TextSelection.collapsed(
                                                    offset: 20),
                                          );
                                        }
                                        setState(() =>
                                            _editNickname = _nicknameCtrl.text);
                                      },
                                      onSubmitted: (_) => _saveNickname(),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937)),
                                      decoration: const InputDecoration(
                                        hintText: '닉네임을 입력하세요',
                                        hintStyle: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF9CA3AF)),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_editNickname.length}/20',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFD1D5DB)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: '※ 닉네임을 설정하면 ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '30일간 변경할 수 없습니다.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _showEditSheet = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '취소',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF374151)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _editNickname.trim().isEmpty
                                        ? null
                                        : _saveNickname,
                                    child: AnimatedOpacity(
                                      opacity: _editNickname.trim().isEmpty
                                          ? 0.3
                                          : 1.0,
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF000000),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '저장',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      ),
    );
  }
}

/// 마이페이지 카드 (사장님 마이페이지 _OwnerCardSection과 동일한 스타일).
/// title이 있으면 카드 맨 위에 섹션 제목을 포함한다.
class _MyCardSection extends StatelessWidget {
  final String? title;
  final Widget child;

  const _MyCardSection({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF000000),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
            child,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// 즐겨찾기 / 스탬프북 / 내 쿠폰함 바로가기 버튼 (세로 아이콘 + 라벨, 우상단 배지)
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showDot;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: const Color(0xFF000000)),
                if (showDot)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final dynamic reward; // UserReward
  final bool loadFailed;
  final VoidCallback? onRetry;

  const _RewardCard({
    required this.reward,
    this.loadFailed = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final today = reward.todayStamps as int;

    return GestureDetector(
      onTap: () {
        if (loadFailed) {
          onRetry?.call();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RewardScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFF000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded,
                        size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '오늘의 스탬프',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '오늘 $today / 3',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ],
              ),
              if (loadFailed) ...[
                const SizedBox(height: 8),
                const Text(
                  '스탬프 정보를 불러오지 못했어요. 탭해서 다시 시도',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF000000),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 10.0;
                  final cellSize = (constraints.maxWidth - gap * 2) / 3 * 0.85;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(3, (i) {
                        final filled = i < today.clamp(0, 3);
                        return Opacity(
                          opacity: filled ? 1.0 : 0.2,
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: const BoxDecoration(
                              color: Color(0xFF000000),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: StampRiceBallIcon(size: cellSize * 0.55),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
