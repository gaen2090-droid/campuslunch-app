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
  final _photoPageController = PageController();
  int _photoIndex = 0;

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

  @override
  void dispose() {
    _photoPageController.dispose();
    super.dispose();
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
            // ── 사진 캐러셀 + 플로팅 헤더 ──
            SizedBox(
              height: _hasImage ? 220 : safeTop + 16 + 36 + 12,
              width: double.infinity,
              child: Stack(
                children: [
                  // 대표사진 + 메뉴사진 캐러셀 (사진 0장이면 영역 자체를 접음)
                  if (_hasImage)
                    Builder(builder: (context) {
                      final photos = <String>[
                        if (r.imageUrl.isNotEmpty) r.imageUrl,
                        ...r.menuPhotoUrls,
                      ];
                      return SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: PageView.builder(
                          controller: _photoPageController,
                          itemCount: photos.length,
                          onPageChanged: (i) => setState(() => _photoIndex = i),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return RestaurantImage(
                                url: photos[i],
                                fallback: () => const RiceBallIcon(size: null),
                                onFallbackChanged: (hasFallback) {
                                  if (hasFallback == !_hasImage) return;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) setState(() => _hasImage = !hasFallback);
                                  });
                                },
                              );
                            }
                            return RestaurantImage(url: photos[i]);
                          },
                        ),
                      );
                    }),

                  // 페이지 인디케이터 (사진 2장 이상일 때만)
                  if (_hasImage && (1 + r.menuPhotoUrls.length) > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(1 + r.menuPhotoUrls.length, (i) {
                          final active = i == _photoIndex;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _photoPageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: active ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withAlpha(120),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  // 이미지 출처 (대표사진: 사장님 등록 여부에 따라 구분, 메뉴사진: 항상 사장님)
                  if (_hasImage)
                    Positioned(
                      right: 12,
                      bottom: (1 + r.menuPhotoUrls.length) > 1 ? 24 : 12,
                      child: Text(
                        _photoIndex == 0
                            ? (r.imageSource == 'owner' ? '출처: 사장님' : '출처: Google Maps')
                            : '출처: 사장님',
                        style: const TextStyle(
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
                                    ? const Color(0xFF111827)
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

            if (r.ownerNotice.isNotEmpty)
              _OwnerNoticeBanner(notice: r.ownerNotice),

            if (_ownerSeatUpdate != null &&
                _ownerSeatUpdate!.isVisibleAt(DateTime.now()))
              OwnerSeatMessageCard(update: _ownerSeatUpdate!),

            if (_recentReports.isNotEmpty)
              _RecentReportsSection(
                reports: _recentReports,
                showPriorityNote: ownerPriorityActive,
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '추후 축적된 제보 데이터를 바탕으로 AI 기반 혼잡도 예측 정보 별도 제공 예정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (r.menu.isNotEmpty) _MenuSection(menu: r.menu, formatPrice: _formatPrice),

            SizedBox(height: 88 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
      floatingActionButton: _ActionButtonBar(
        showReportButton: !provider.hasOwnerTab,
        reportEnabled: r.status != '영업안함',
        onReport: () => ReportSheet.show(
          context,
          r,
          (status) => _submitReport(r.id, status),
        ),
        onNavigate: () => _navigate(r),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

class _OwnerNoticeBanner extends StatelessWidget {
  final String notice;
  const _OwnerNoticeBanner({required this.notice});

  void _showFull(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign_outlined, size: 18, color: Color(0xFF6B7280)),
                  SizedBox(width: 8),
                  Text(
                    '매장 공지',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notice,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => _showFull(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign_outlined, size: 15, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  notice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final List<MenuItem> menu;
  final String Function(int) formatPrice;
  const _MenuSection({required this.menu, required this.formatPrice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '메뉴',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            ...menu.asMap().entries.map((e) {
              final isLast = e.key == menu.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.value.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatPrice(e.value.price)}원',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonBar extends StatelessWidget {
  final bool showReportButton;
  final bool reportEnabled;
  final VoidCallback onReport;
  final VoidCallback onNavigate;

  const _ActionButtonBar({
    required this.showReportButton,
    required this.reportEnabled,
    required this.onReport,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final navigateButton = GestureDetector(
      onTap: onNavigate,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: showReportButton ? Colors.white : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: showReportButton
              ? Border.all(color: const Color(0xFF111827), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.navigation_outlined,
                size: 15,
                color: showReportButton ? const Color(0xFF111827) : Colors.white),
            const SizedBox(width: 5),
            Text(
              '길찾기',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: showReportButton ? const Color(0xFF111827) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: showReportButton
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Opacity(
                    opacity: reportEnabled ? 1.0 : 0.4,
                    child: GestureDetector(
                      onTap: reportEnabled ? onReport : null,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined, size: 15, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              '혼잡도 제보하기',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: navigateButton),
              ],
            )
          : navigateButton,
    );
  }
}

class _RecentReportsSection extends StatelessWidget {
  final List<RecentCrowdReport> reports;
  final bool showPriorityNote;
  const _RecentReportsSection({
    required this.reports,
    this.showPriorityNote = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
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
              final prefix = r.isOwner ? '사장님 · ' : '';
              final statusLabel = r.status == '웨이팅많음' ? '웨이팅' : r.status;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '$prefix$statusLabel · ${formatUpdateAgeWithTime(r.createdAt)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              );
            }),
            if (showPriorityNote) ...[
              const SizedBox(height: 4),
              const Text(
                '사장님의 제보가 있는 경우 5분간 혼잡도 상태를 유지해요.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFEF4444),
                  height: 1.4,
                ),
              ),
            ],
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
