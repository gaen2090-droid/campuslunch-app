import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/restaurant.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurants = context.watch<AppProvider>().restaurants;
    final previews = restaurants
        .where((r) => r.status == '여유로움' || r.status == '약간혼잡')
        .toList()
      ..sort((a, b) => b.totalReports.compareTo(a.totalReports));
    final top3 = previews.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F7),
      body: Stack(
        children: [
          // 블러 원형 장식
          Positioned(
            right: -80,
            top: 60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD4B8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: 80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFFED7AA).withAlpha(180),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // 메인 콘텐츠
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 로고
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6207),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFFFD4B8),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '캠퍼스런치',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF6207),
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            '중앙대 맛집 혼잡도',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),

                  // 타이틀
                  const Text(
                    '지금 갈 수 있는\n중앙대 맛집 찾기',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      height: 1.16,
                      letterSpacing: -1.87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '실시간 제보로 확인하는\n중앙대 맛집 혼잡도',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4B5563),
                      height: 1.75,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // 미리보기 카드
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 45,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '지금 바로 입장 가능',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...top3.map((r) => _RestaurantRow(restaurant: r)),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 시작 버튼
                  GestureDetector(
                    onTap: () => context.read<AppProvider>().completeOnboarding(),
                    child: Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6207),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFFFD4B8),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '시작하기',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  final Restaurant restaurant;
  const _RestaurantRow({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final meta = statusMetaMap[restaurant.status];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: restaurant.image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: restaurant.image,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _InitialCircle(name: restaurant.name),
                  )
                : _InitialCircle(name: restaurant.name),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  restaurant.region == restaurant.cuisine
                      ? restaurant.region
                      : '${restaurant.region} · ${restaurant.cuisine}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          if (meta != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Color(meta.bgColor),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                restaurant.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(meta.color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialCircle extends StatelessWidget {
  final String name;
  const _InitialCircle({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3EC),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFF6207),
          ),
        ),
      ),
    );
  }
}
