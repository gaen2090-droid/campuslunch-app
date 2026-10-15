import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/restaurant_image.dart';
import '../widgets/rice_ball_icon.dart';
import 'detail_screen.dart';

/// 마이 > 고객지원 > "우리와 함께하는 매장".
/// 사장님 인증이 끝나 owner_id가 연결된 매장을 보여준다. 별도 목록을 두지 않고
/// 매장 데이터(owner_id)에서 바로 만들기 때문에, 인증이 끝나면 자동으로 추가되고
/// 인증이 해제되면 자동으로 빠진다.
class PartnerRestaurantsScreen extends StatefulWidget {
  const PartnerRestaurantsScreen({super.key});

  @override
  State<PartnerRestaurantsScreen> createState() =>
      _PartnerRestaurantsScreenState();
}

class _PartnerRestaurantsScreenState extends State<PartnerRestaurantsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  /// 방금 인증된 매장이 바로 보이도록 열 때 최신 목록을 한 번 받아온다.
  Future<void> _refresh() async {
    try {
      await context
          .read<AppProvider>()
          .reloadRestaurantsOnly()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Partners] reload skipped: $e');
    }
  }

  List<Restaurant> _partners(List<Restaurant> all) {
    final list = all
        .where((r) => r.isActive && (r.ownerId ?? '').isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final partners = _partners(context.watch<AppProvider>().restaurants);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '우리와 함께하는 매장',
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
        child: partners.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '아직 함께하는 매장이 없어요.\n사장님 인증을 마친 매장이 여기에 모여요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: partners.length + 1,
                separatorBuilder: (_, i) =>
                    SizedBox(height: i == 0 ? 14 : 10),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return const Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                        children: [
                          TextSpan(text: '사장님이 '),
                          TextSpan(
                            text: '직접 제보',
                            style: TextStyle(color: AppColors.primaryCta),
                          ),
                          TextSpan(text: '한 혼잡도를 확인할 수 있어요'),
                        ],
                      ),
                    );
                  }
                  final r = partners[i - 1];
                  return _PartnerCard(
                    restaurant: r,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DetailScreen(restaurant: r)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// 혼잡도 없이 매장 소개만 보여주는 카드.
class _PartnerCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _PartnerCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: RestaurantImage(
                  url: r.imageUrl,
                  fallback: () => const RiceBallIcon(size: 56),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.area == r.category ? r.area : '${r.area} · ${r.category}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}
