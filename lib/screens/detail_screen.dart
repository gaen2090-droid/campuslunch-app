import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/report_sheet.dart';

class DetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  const DetailScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final r = provider.restaurants.firstWhere(
      (x) => x.id == restaurant.id,
      orElse: () => restaurant,
    );
    final isBookmarked = provider.bookmarks.contains(r.id);
    final statusColor = _statusColor(r.status);
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 이미지 + 플로팅 헤더 ──
            Stack(
              children: [
                // 전체폭 이미지
                SizedBox(
                  height: r.image.isNotEmpty ? 220 : safeTop + 72,
                  width: double.infinity,
                  child: r.image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: r.image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFFFF3EC),
                            child: Center(
                              child: Text(r.emoji,
                                  style: const TextStyle(fontSize: 56)),
                            ),
                          ),
                        )
                      : Container(color: const Color(0xFFFFF9F7)),
                ),

                // 플로팅 헤더 버튼
                Positioned(
                  top: safeTop + 16,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _HeaderBtn(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.chevron_left,
                            size: 18, color: Color(0xFF374151)),
                      ),
                      Row(
                        children: [
                          _HeaderBtn(
                            onTap: () => provider.toggleBookmark(r.id),
                            child: Icon(
                              isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              size: 16,
                              color: isBookmarked
                                  ? const Color(0xFFFF6207)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HeaderBtn(
                            onTap: () {},
                            child: const Icon(Icons.share_outlined,
                                size: 16, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── 기본 정보 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.96,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.region == r.cuisine
                              ? r.region
                              : '${r.region} · ${r.cuisine}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    r.status,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── 영업시간 ──
            if (r.hours.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 8),
                    Text(
                      r.hours,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 액션 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => ReportSheet.show(
                      context,
                      r,
                      (status) {
                        context.read<AppProvider>().reportStatus(r.id, status);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text(
                            '제보가 반영됐어요. 감사해요!',
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
                      },
                    ),
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6207),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFFFE4CC),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            '혼잡도 제보하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _navigate(r),
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD4B8)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation_outlined,
                              size: 16, color: Color(0xFFFF6207)),
                          SizedBox(width: 6),
                          Text(
                            '길찾기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF6207),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 메뉴 ──
            if (r.menu.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '메뉴',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...r.menu.asMap().entries.map((e) {
                      final isLast = e.key == r.menu.length - 1;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.value.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_formatPrice(e.value.price)}원',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF6207),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                                height: 1, color: Color(0xFFF3F1EB)),
                        ],
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case '여유로움': return const Color(0xFF22C55E);
      case '약간혼잡': return const Color(0xFFF59E0B);
      case '자리없음': return const Color(0xFFEF4444);
      default: return const Color(0xFF9CA3AF);
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  void _navigate(Restaurant r) {
    final url = Uri.parse(
        'https://map.kakao.com/link/search/${Uri.encodeComponent(r.name)}');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _HeaderBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _HeaderBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 8),
          ],
        ),
        child: child,
      ),
    );
  }
}
