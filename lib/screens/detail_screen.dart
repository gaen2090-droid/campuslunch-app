import 'package:flutter/material.dart';
import '../widgets/restaurant_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/crowd_status_label.dart';
import '../widgets/business_hours_section.dart';
import '../widgets/owner_seat_message_card.dart';
import '../models/owner_seat_update.dart';
import '../utils/report_feedback.dart';
import '../widgets/report_sheet.dart';

class DetailScreen extends StatefulWidget {
  final Restaurant restaurant;
  const DetailScreen({super.key, required this.restaurant});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  OwnerSeatUpdate? _ownerSeatUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      final r = provider.restaurants.firstWhere(
        (x) => x.id == widget.restaurant.id,
        orElse: () => widget.restaurant,
      );
      if (r.status == '영업안함') {
        _loadOwnerSeatUpdate();
        return;
      }
      ReportSheet.show(context, r, (status) {
        submitCrowdReportFeedback(context, r.id, status);
      });
      _loadOwnerSeatUpdate();
    });
  }

  Future<void> _loadOwnerSeatUpdate() async {
    final update = await context
        .read<AppProvider>()
        .fetchOwnerSeatUpdate(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _ownerSeatUpdate = update);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final r = provider.restaurants.firstWhere(
      (x) => x.id == widget.restaurant.id,
      orElse: () => widget.restaurant,
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
                  height: r.imageUrl.isNotEmpty ? 220 : safeTop + 72,
                  width: double.infinity,
                  child: RestaurantImage(
                    url: r.imageUrl,
                    fallback: () => Container(
                      color: const Color(0xFF2D2D2D),
                      child: const Center(
                        child: Icon(Icons.restaurant, size: 56, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                  ),
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
                                  ? const Color(0xFF1A1A1A)
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

            // ── 기본 정보 (좁은 화면·큰 글꼴에서도 오버플로우 없음) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final statusMaxW = constraints.maxWidth * 0.36;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                letterSpacing: -0.96,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r.area == r.category
                                  ? r.area
                                  : '${r.area} · ${r.category}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: statusMaxW),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              r.status == '영업안함'
                                  ? r.status
                                  : r.hasCrowdUpdate
                                      ? r.status
                                      : '제보필요',
                              maxLines: 1,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: (r.status != '영업안함' && !r.hasCrowdUpdate)
                                    ? const Color(0xFF9CA3AF)
                                    : statusColor,
                                height: 1.15,
                              ),
                            ),
                            if (r.status != '영업안함' && r.hasCrowdUpdate) ...[
                              const SizedBox(height: 4),
                              Text(
                                formatUpdateAge(r.updated),
                                maxLines: 1,
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            BusinessHoursSection(hours: r.hours),

            if (_ownerSeatUpdate != null &&
                _ownerSeatUpdate!.isVisibleAt(DateTime.now()))
              OwnerSeatMessageCard(update: _ownerSeatUpdate!),

            // ── 액션 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  Opacity(
                    opacity: r.status == '영업안함' ? 0.4 : 1.0,
                    child: GestureDetector(
                    onTap: r.status == '영업안함' ? null : () => ReportSheet.show(
                      context,
                      r,
                      (status) => submitCrowdReportFeedback(context, r.id, status),
                    ),
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2FF89),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: Color(0xFF1A1A1A)),
                          SizedBox(width: 8),
                          Text(
                            '혼잡도 제보하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation_outlined,
                              size: 16, color: Color(0xFF1A1A1A)),
                          SizedBox(width: 6),
                          Text(
                            '길찾기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_formatPrice(e.value.price)}원',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1A1A),
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

            SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case '여유로움': return const Color(0xFFA0FF46);
      case '약간혼잡': return const Color(0xFFFFFF00);
      case '자리없음': return const Color(0xFFF52E7F);
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
