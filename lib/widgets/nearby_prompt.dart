import 'package:flutter/material.dart';
import 'restaurant_image.dart';
import 'rice_ball_icon.dart';
import '../models/restaurant.dart';

class NearbyPrompt extends StatelessWidget {
  final List<Restaurant> restaurants;
  final VoidCallback onClose;
  final ValueChanged<Restaurant> onReport;

  const NearbyPrompt({
    super.key,
    required this.restaurants,
    required this.onClose,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...restaurants]..sort((a, b) => a.distance.compareTo(b.distance));
    final nearby = sorted.where((r) => r.distance <= 50).take(3).toList();

    if (nearby.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 주변 가까운 매장이에요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '혼잡도를 알려주시면 여유로운 식사에 보탬이 돼요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: nearby.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < nearby.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => onReport(r),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: Colors.white,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 56,
                              width: double.infinity,
                              child: RestaurantImage(url: r.imageUrl, fallback: () => const _IconBox()),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              child: Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0FDF4),
      child: const Center(
        child: RiceBallIcon(size: 22, color: Color(0xFF16A34A)),
      ),
    );
  }
}
