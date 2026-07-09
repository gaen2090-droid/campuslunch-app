import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import 'bookmark_list_screen.dart';
import 'reward_screen.dart';
import 'settings_screen.dart';
import '../widgets/rice_ball_icon.dart';

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
    final bookmarkCount =
        provider.restaurants.where((r) => provider.bookmarks.contains(r.id)).length;
    final hasOwner = provider.hasOwnerTab;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 페이지 타이틀 ──
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '마이페이지',
                        style: TextStyle(
                          fontFamily: 'OkDanDan',
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF5E8C4A),
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.settings_outlined,
                            size: 20, color: Color(0xFF5E8C4A)),
                      ),
                    ),
                  ],
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 내 스탬프 ──
              _RewardCard(
                reward: provider.reward,
                loadFailed: provider.rewardLoadFailed,
                onRetry: () => provider.fetchMyReward(),
              ),

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
                            color: Color(0xFF5E8C4A)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '즐겨찾기한 매장',
                            style: TextStyle(
                                fontFamily: 'OkDanDan',
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$bookmarkCount',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF5E8C4A)),
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
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://sheer-parent-7ed.notion.site/385c273f6bec80eda925df4945c021b7?source=copy_link'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 8,
                          offset: const Offset(0, 1))
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.help_rounded,
                            size: 16,
                            color: Color(0xFF5E8C4A)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '캠퍼스런치 사용 가이드',
                            style: TextStyle(
                                fontFamily: 'OkDanDan',
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827)),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: Color(0xFFD1D5DB)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 사장님 ──
              if (hasOwner) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => provider.setMainTabIndex(0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFE0B0)),
                    ),
                    child: const Center(
                      child: Text(
                        '내 매장 혼잡도 관리',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5E8C4A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                                      controller: _nicknameCtrl,
                                      onChanged: (v) {
                                        if (v.length > 20) {
                                          _nicknameCtrl.value = TextEditingValue(
                                            text: v.substring(0, 20),
                                            selection: const TextSelection.collapsed(offset: 20),
                                          );
                                        }
                                        setState(() => _editNickname = _nicknameCtrl.text);
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
                                          color: const Color(0xFF9ECA8B),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '저장',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF111827)),
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
    final total = reward.totalStamps as int;
    final today = reward.todayStamps as int;
    final remaining = (20 - total).clamp(0, 20);

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: total >= 20 ? const Color(0xFFBFE0B0) : const Color(0xFFE5E7EB),
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
                  const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF5E8C4A)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '오늘의 스탬프',
                      style: TextStyle(
                        fontFamily: 'OkDanDan',
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '오늘 $today / 3',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5E8C4A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
                ],
              ),
              if (loadFailed) ...[
                const SizedBox(height: 8),
                const Text(
                  '스탬프 정보를 불러오지 못했어요. 탭해서 다시 시도',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 10.0;
                  final cellSize = (constraints.maxWidth - gap * 2) / 3;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (i) {
                      final filled = i < today.clamp(0, 3);
                      return Container(
                        width: cellSize,
                        height: cellSize,
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
                              ? StampRiceBallIcon(size: cellSize * 0.55)
                              : Opacity(
                                  opacity: 0.35,
                                  child: StampRiceBallIcon(size: cellSize * 0.55),
                                ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                remaining > 0
                    ? '아메리카노 쿠폰까지 $remaining개 남았어요'
                    : '커피 쿠폰을 받을 수 있어요!',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

