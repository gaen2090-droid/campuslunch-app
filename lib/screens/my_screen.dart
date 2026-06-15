import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/owner_verify_sheet.dart';
import 'bookmark_list_screen.dart';
import 'reward_screen.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  bool _showEditSheet = false;
  String _editNickname = '';
  bool _lunchPush = false;
  bool _dinnerPush = false;
  bool _showOwnerVerify = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final provider = context.read<AppProvider>();
      _lunchPush = provider.lunchPushEnabled;
      _dinnerPush = provider.dinnerPushEnabled;
    }
  }

  void _openEdit(String current) {
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
    final bookmarkCount =
        provider.restaurants.where((r) => provider.bookmarks.contains(r.id)).length;
    final isOwner = provider.userRole == 'owner';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 페이지 타이틀 ──
              const Padding(
                padding: EdgeInsets.only(bottom: 20, top: 8),
                child: Text(
                  '마이페이지',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.8,
                  ),
                ),
              ),

              // ── 프로필 카드 ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 1))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                          child: const Center(
                              child: Icon(Icons.person, size: 22, color: Color(0xFF9CA3AF))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            provider.nickname.isEmpty ? '앙대 학생' : provider.nickname,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openEdit(provider.nickname),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_outlined,
                                size: 14, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => provider.logout(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: const Center(
                          child: Text(
                            '로그아웃',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _confirmWithdraw(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFEE2E2)),
                        ),
                        child: const Center(
                          child: Text(
                            '회원 탈퇴',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 내 리워드 ──
              _RewardCard(reward: provider.reward),

              const SizedBox(height: 16),

              // ── 저장한 매장 ──
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookmarkListScreen()),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 8,
                          offset: const Offset(0, 1))
                    ],
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark,
                            size: 16,
                            color: Color(0xFF1A1A1A)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '저장한 매장',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA0FF46),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$bookmarkCount',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A1A)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right,
                            size: 16, color: Color(0xFFD1D5DB)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── 푸시 알림 설정 ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 1))
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications,
                            size: 16, color: Color(0xFF1A1A1A)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '푸시 알림 설정',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827)),
                          ),
                        ),
                        const Text(
                          'ON/OFF',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _ToggleRow(
                      title: '점심 피크 추천 알림',
                      desc: '평일 12:00에 여유로운 매장을 알려드려요!',
                      enabled: _lunchPush,
                      onToggle: () async {
                        final next = !_lunchPush;
                        setState(() => _lunchPush = next);
                        await context.read<AppProvider>().setLunchPush(next);
                        if (!context.mounted) return;
                        if (next) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text(
                              '평일 12:00에 알림을 보내드릴게요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            backgroundColor: const Color(0xFF111827),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            duration: const Duration(milliseconds: 1600),
                            elevation: 0,
                          ));
                        }
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _ToggleRow(
                      title: '저녁 피크 추천 알림',
                      desc: '평일 18:00에 여유로운 매장을 알려드려요!',
                      enabled: _dinnerPush,
                      onToggle: () async {
                        final next = !_dinnerPush;
                        setState(() => _dinnerPush = next);
                        await context.read<AppProvider>().setDinnerPush(next);
                        if (!context.mounted) return;
                        if (next) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text(
                              '평일 18:00에 알림을 보내드릴게요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            backgroundColor: const Color(0xFF111827),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            duration: const Duration(milliseconds: 1600),
                            elevation: 0,
                          ));
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── 사장님 ──
              if (!isOwner) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => setState(() => _showOwnerVerify = true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        '사장님 인증',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ),
              ] else if (provider.hasOwnerTab) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => provider.setMainTabIndex(0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2FFE4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD5FFA8)),
                    ),
                    child: const Center(
                      child: Text(
                        '내 매장 혼잡도 관리',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // ── 개발자 옵션 ──
              const SizedBox(height: 40),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Color(0xFFE5E7EB),
                          style: BorderStyle.solid)),
                ),
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '개발자 옵션',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD1D5DB)),
                    ),
                    const SizedBox(height: 12),
                    if (kDebugMode) ...[
                      GestureDetector(
                        onTap: () async {
                          final msg = await context
                              .read<AppProvider>()
                              .debugSchedulePushTest();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD5FFA8)),
                          ),
                          child: const Center(
                            child: Text(
                              '30초 후 푸시 테스트 (앱 종료 후 확인)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final msg = await context
                              .read<AppProvider>()
                              .debugPushDiagnostics();
                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('푸시 디버그'),
                              content: Text(msg),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('닫기'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Center(
                            child: Text(
                              '푸시 예약 상태 보기',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GestureDetector(
                      onTap: () => _confirmReset(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              style: BorderStyle.solid),
                        ),
                        child: const Center(
                          child: Text(
                            '앱 초기화 (첫 화면으로)',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD1D5DB)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── 사장님 인증 시트 ──
        if (_showOwnerVerify)
          Positioned.fill(
            child: OwnerVerifySheet(
              onClose: () => setState(() => _showOwnerVerify = false),
              onSuccess: (_) {
                setState(() => _showOwnerVerify = false);
                context.read<AppProvider>().setMainTabIndex(0);
              },
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
                            MediaQuery.of(context).padding.bottom + 24),
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
                                  color: Color(0xFF111827)),
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
                                      controller: TextEditingController.fromValue(
                                        TextEditingValue(
                                          text: _editNickname,
                                          selection: TextSelection.collapsed(
                                              offset: _editNickname.length),
                                        ),
                                      ),
                                      onChanged: (v) => setState(
                                          () => _editNickname = v.length > 20 ? v.substring(0, 20) : v),
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
                                        borderRadius:
                                            BorderRadius.circular(16),
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
                                      opacity:
                                          _editNickname.trim().isEmpty ? 0.3 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC2FF89),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '저장',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1A1A1A)),
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
    );
  }

  void _confirmWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('회원 탈퇴',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '계정과 프로필이 삭제되며 복구할 수 없어요.\n'
          '카카오 로그인 계정은 카카오 연결도 해제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err =
                  await context.read<AppProvider>().withdrawAccount();
              if (!context.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
              }
            },
            child: const Text('탈퇴하기',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('앱 초기화',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('모든 데이터를 초기화하고 첫 화면으로 돌아갑니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소',
                  style: TextStyle(color: Color(0xFF9CA3AF)))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AppProvider>().devReset();
            },
            child: const Text('초기화',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final dynamic reward; // UserReward

  const _RewardCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final total = reward.totalStamps as int;
    final today = reward.todayStamps as int;
    final remaining = (20 - total).clamp(0, 20);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RewardScreen()),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: total >= 20 ? const Color(0xFFD5FFA8) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF1A1A1A)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '내 리워드',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA0FF46),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '오늘 $today / 3',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '스탬프 $total',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Text(
                    ' / 20',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (total / 20).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFC2FF89)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                remaining > 0
                    ? '바나프레소 아메리카노까지 $remaining개 남았어요'
                    : '쿠폰을 받을 수 있어요!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: remaining == 0 ? const Color(0xFF1A1A1A) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String desc;
  final bool enabled;
  final VoidCallback onToggle;

  const _ToggleRow({
    required this.title,
    required this.desc,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color:
                    enabled ? const Color(0xFFC2FF89) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
