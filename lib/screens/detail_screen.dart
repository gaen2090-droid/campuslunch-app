import 'package:flutter/material.dart';
import '../widgets/restaurant_image.dart';
import '../widgets/rice_ball_icon.dart';
import 'package:provider/provider.dart';
import '../utils/navigation_helper.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/crowd_status_label.dart';
import '../widgets/business_hours_section.dart';
import '../widgets/owner_seat_message_card.dart';
import '../models/owner_seat_update.dart';
import '../utils/report_feedback.dart';
import '../widgets/report_sheet.dart';
import '../widgets/share_sheet.dart';
import '../models/crowd_report.dart';

class DetailScreen extends StatefulWidget {
  final Restaurant restaurant;
  const DetailScreen({super.key, required this.restaurant});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  OwnerSeatUpdate? _ownerSeatUpdate;
  List<RecentCrowdReport> _recentReports = [];
  late bool _hasImage;

  @override
  void initState() {
    super.initState();
    _hasImage = widget.restaurant.imageUrl.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      final r = provider.restaurants.firstWhere(
        (x) => x.id == widget.restaurant.id,
        orElse: () => widget.restaurant,
      );
      // 사장님이 자기 매장을 미리보기할 때는 실제 유저 방문이 아니므로 집계에서 제외.
      if (!provider.hasOwnerTab) {
        provider.recordDetailView(r.id);
      }
      // 사장님이 자기 매장을 미리보기할 때는 제보 유도 시트를 띄우지 않는다.
      if (r.status == '영업안함' || provider.hasOwnerTab) {
        _loadOwnerSeatUpdate();
        _loadRecentReports();
        return;
      }
      ReportSheet.show(context, r, (status) {
        _submitReport(r.id, status);
      });
      _loadOwnerSeatUpdate();
      _loadRecentReports();
    });
  }

  Future<void> _loadOwnerSeatUpdate() async {
    final update = await context
        .read<AppProvider>()
        .fetchOwnerSeatUpdate(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _ownerSeatUpdate = update);
  }

  Future<void> _loadRecentReports() async {
    final reports = await context
        .read<AppProvider>()
        .fetchRecentCrowdReports(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _recentReports = reports.take(3).toList());
  }

  Future<void> _submitReport(String restaurantId, String status) async {
    await submitCrowdReportFeedback(context, restaurantId, status);
    if (!mounted) return;
    await _loadRecentReports();
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
    final ownerPriorityActive = r.hasCrowdUpdate &&
        r.crowdBaseSource == 'owner' &&
        r.updatedAt != null &&
        DateTime.now().difference(r.updatedAt!) < const Duration(minutes: 5);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 이미지 + 플로팅 헤더 ──
            SizedBox(
              height: _hasImage ? 220 : safeTop + 16 + 36 + 12,
              width: double.infinity,
              child: Stack(
                children: [
                  // 전체폭 이미지 (사진 없으면 영역 자체를 접음)
                  if (_hasImage)
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: RestaurantImage(
                        url: r.imageUrl,
                        fallback: () => const RiceBallIcon(size: null),
                        onFallbackChanged: (hasFallback) {
                          if (hasFallback == !_hasImage) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _hasImage = !hasFallback);
                          });
                        },
                      ),
                    ),

                  // 이미지 출처 (구글 지도 사진 사용 — 우측 하단, 가독성 위해 그림자 적용)
                  if (_hasImage)
                    const Positioned(
                      right: 12,
                      bottom: 12,
                      child: Text(
                        '출처: Google Maps',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
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
                                    ? const Color(0xFF5E8C4A)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _HeaderBtn(
                              onTap: () => showShareSheet(context, r),
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
                                      ? (r.status == '웨이팅많음' ? '🔥웨이팅' : r.status)
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
                                r.crowdBaseSource == 'owner'
                                    ? '사장님 · ${formatUpdateAgeFromDateTime(r.updatedAt)}'
                                    : formatUpdateAgeFromDateTime(r.updatedAt),
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

            if (ownerPriorityActive) const _OwnerPriorityWindowCard(),

            if (_recentReports.isNotEmpty) _RecentReportsSection(reports: _recentReports),

            // ── 액션 버튼 (사장님이 자기 매장을 미리보기할 때는 제보 버튼 숨김) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  if (!provider.hasOwnerTab) ...[
                    Opacity(
                      opacity: r.status == '영업안함' ? 0.4 : 1.0,
                      child: GestureDetector(
                      onTap: r.status == '영업안함' ? null : () => ReportSheet.show(
                        context,
                        r,
                        (status) => _submitReport(r.id, status),
                      ),
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF9ECA8B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 16, color: Color(0xFF111827)),
                            SizedBox(width: 8),
                            Text(
                              '혼잡도 제보하기',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  GestureDetector(
                    onTap: () => _navigate(r),
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF5E8C4A), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation_outlined,
                              size: 16, color: Color(0xFF5E8C4A)),
                          SizedBox(width: 6),
                          Text(
                            '길찾기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5E8C4A),
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
                                    color: Color(0xFF5E8C4A),
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
      case '여유로움': return const Color(0xFF4C9C2A);
      case '약간혼잡': return const Color(0xFFF59E0B);
      case '자리없음': return const Color(0xFFF97316);
      case '웨이팅많음': return const Color(0xFFEF4444);
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
    openInAppDirections(context, r);
  }
}

class _OwnerPriorityWindowCard extends StatelessWidget {
  const _OwnerPriorityWindowCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFE0B0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chat_bubble_outline,
                  size: 18, color: Color(0xFF5E8C4A)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '사장님의 제보가 있는 경우 5분간 혼잡도 상태를 유지해요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4C9C2A),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentReportsSection extends StatelessWidget {
  final List<RecentCrowdReport> reports;
  const _RecentReportsSection({required this.reports});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFE0B0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 제보',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            ...reports.map((r) {
              final minutesAgo = DateTime.now().difference(r.createdAt).inMinutes;
              final prefix = r.isOwner ? '사장님 · ' : '';
              final statusLabel = r.status == '웨이팅많음' ? '웨이팅' : r.status;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '$prefix$statusLabel · ${formatUpdateAge(minutesAgo)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
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
