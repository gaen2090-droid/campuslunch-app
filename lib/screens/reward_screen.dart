import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'coupon_box_screen.dart';
import '../widgets/rice_ball_icon.dart';

class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMyReward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final reward = provider.reward;
    final gifticons = provider.visibleMyGifticons;
    final total = reward.totalStamps;
    final today = reward.todayStamps;
    const target = 20;
    final remaining = target - total;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F8F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '내 스탬프',
          style: TextStyle(
            fontFamily: 'OkDanDan',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF5E8C4A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchMyReward(),
        color: const Color(0xFF5E8C4A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.rewardLoadFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 18, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '스탬프 정보를 불러오지 못했어요',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => provider.fetchMyReward(),
                          child: const Text(
                            '다시 시도',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF5E8C4A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // ── 스탬프 현황 카드 ──
              _StampSummaryCard(total: total, today: today, remaining: remaining),
              const SizedBox(height: 20),

              // ── 스탬프북 ──
              _SectionTitle('스탬프북'),
              const SizedBox(height: 12),
              _StampGrid(filled: total, target: target),
              const SizedBox(height: 20),

              // ── 쿠폰함 바로가기 ──
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CouponBoxScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: Text('🎁', style: TextStyle(fontSize: 26))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '쿠폰함',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              gifticons.isEmpty ? '받은 쿠폰이 없어요' : '보유 쿠폰 ${gifticons.length}개',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111827),
        letterSpacing: -0.3,
      ),
    );
  }
}

class _StampSummaryCard extends StatelessWidget {
  final int total;
  final int today;
  final int remaining;

  const _StampSummaryCard({required this.total, required this.today, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBFE0B0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '스탬프 현황',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF374151)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '오늘 $today / 999',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5E8C4A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF5E8C4A), height: 1),
              ),
              const Text(
                ' / 20',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (total / 20).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF5E8C4A)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            remaining > 0
                ? '아메리카노 쿠폰까지 $remaining개 남았어요'
                : '쿠폰이 발급됐어요!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: remaining > 0 ? const Color(0xFF6B7280) : const Color(0xFF5E8C4A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '하루 최대 999개의 스탬프를 획득할 수 있어요. (테스트)',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _StampGrid extends StatelessWidget {
  final int filled;
  final int target;

  const _StampGrid({required this.filled, required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: target,
        itemBuilder: (_, i) => _StampCell(filled: i < filled),
      ),
    );
  }
}

class _StampCell extends StatelessWidget {
  final bool filled;
  const _StampCell({required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
            ? const StampRiceBallIcon(size: 30)
            : const Opacity(
                opacity: 0.35,
                child: StampRiceBallIcon(size: 30),
              ),
      ),
    );
  }
}


