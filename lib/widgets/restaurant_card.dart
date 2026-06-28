import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../utils/crowd_status_label.dart';
import 'restaurant_image.dart';
import 'rice_ball_icon.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantCard({super.key, required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final noReport = r.status != '영업안함' && !r.hasCrowdUpdate;
    final displayStatus = noReport ? '제보필요' : r.status;
    final meta = crowdStatusMeta(displayStatus);
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
            // 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 48, height: 48,
                child: RestaurantImage(
                  url: r.imageUrl,
                  fallback: () => const _IconBox(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            // 상태 뱃지
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 140),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Color(meta.bgColor),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (displayStatus == '웨이팅많음') ...[
                      const TextSpan(text: '🔥', style: TextStyle(fontSize: 9)),
                      TextSpan(
                        text: '웨이팅',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(meta.color),
                        ),
                      ),
                    ] else
                      TextSpan(
                        text: displayStatus,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(meta.color),
                        ),
                      ),
                    if (r.status != '영업안함' && r.hasCrowdUpdate)
                      TextSpan(
                        text: ' · ${formatUpdateAge(r.updated)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(color: Color(0xFF9ECA8B)),
      child: const Center(
        child: RiceBallIcon(size: 22),
      ),
    );
  }
}

// 추천 히어로 카드 (그라디언트 배너)
class HeroRestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onDetail;
  final VoidCallback onReport;

  const HeroRestaurantCard({
    super.key,
    required this.restaurant,
    required this.onDetail,
    required this.onReport,
  });

  @override
  State<HeroRestaurantCard> createState() => _HeroRestaurantCardState();
}

class _HeroRestaurantCardState extends State<HeroRestaurantCard> {
  bool _isFallback = false;

  void _setFallback(bool value) {
    if (_isFallback == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isFallback = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final hasImage = !_isFallback;
    return GestureDetector(
      onTap: widget.onDetail,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF9ECA8B), width: 2),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
          height: 210,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 배경 이미지
              RestaurantImage(url: r.imageUrl, onFallbackChanged: _setFallback),

              // 하단 다크 그라디언트 (텍스트 가독성)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xCC000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1.0],
                  ),
                ),
              ),

              // 콘텐츠
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 추천 뱃지 (사진 없는 매장은 배경색과 겹치므로 흰색으로 전환)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasImage ? const Color(0xFF9ECA8B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                                color: Color(0xFF111827), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '추천 매장',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.area == r.category ? r.area : '${r.area} · ${r.category}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withAlpha(150)),
                    ),
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        text: '현재 ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withAlpha(150)),
                        children: [
                          TextSpan(
                            text: r.status == '웨이팅많음' ? '🔥웨이팅' : r.status,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                          if (r.status != '영업안함' && r.hasCrowdUpdate)
                            TextSpan(
                              text: ' · ${formatUpdateAge(r.updated)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withAlpha(150),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onDetail,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(50),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text(
                                  '자세히 보기',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onReport,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text(
                                  '혼잡도 제보하기',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF5E8C4A)),
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
            ],
          ),
        ),
        ),
      ),
    );
  }
}
