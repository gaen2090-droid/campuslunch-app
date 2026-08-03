import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant.dart';
import '../providers/app_provider.dart';

/// 사장님 통계 상세 화면: 진초록 배너 + 제보/즐겨찾기/지도 클릭 지표.
class OwnerStatsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const OwnerStatsScreen({super.key, required this.restaurant});

  @override
  State<OwnerStatsScreen> createState() => _OwnerStatsScreenState();
}

class _OwnerStatsScreenState extends State<OwnerStatsScreen> {
  int? _bookmarkCount;
  int? _todayMapClicks;
  int? _totalMapClicks;
  int? _todayReports;
  int? _totalSearchClicks;
  int? _todayDetailViews;
  int? _totalDetailViews;
  DateTime? _verifiedSince;
  bool _verifiedSinceLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final bookmarkCount =
        await provider.fetchOwnerRestaurantBookmarkCount(widget.restaurant.id);
    final engagement =
        await provider.fetchOwnerRestaurantEngagementStats(widget.restaurant.id);
    final verifiedSince =
        await provider.fetchOwnerVerifiedSince(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _bookmarkCount = bookmarkCount;
      _todayMapClicks = engagement['todayMapClicks'];
      _totalMapClicks = engagement['totalMapClicks'];
      _todayReports = engagement['todayReports'];
      _totalSearchClicks = engagement['totalSearchClicks'];
      _todayDetailViews = engagement['todayDetailViews'];
      _totalDetailViews = engagement['totalDetailViews'];
      _verifiedSince = verifiedSince;
      _verifiedSinceLoaded = true;
    });
  }

  /// 매장 자체 등록일이 아니라, 이 사장님이 이 매장에 대해 승인받은 날짜 기준.
  int _daysSinceVerified() {
    final since = _verifiedSince ?? widget.restaurant.createdAt;
    if (since == null) return 0;
    final diff = DateTime.now().difference(since).inDays;
    return diff < 1 ? 1 : diff;
  }

  void _showInfoDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(
          description,
          style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFF000000))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '통계',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF000000), Color(0xFF374151)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '캠퍼스런치 파트너',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _verifiedSinceLoaded
                        ? '${restaurant.name}은\n${_daysSinceVerified()}일동안 함께하고 있어요'
                        : restaurant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              '오늘',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: '오늘 제보수',
                    value: _todayReports == null ? '-' : '$_todayReports건',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: '오늘 지도 클릭수',
                    value: _todayMapClicks == null ? '-' : '$_todayMapClicks회',
                    trailing: _infoIcon(
                      '지도 클릭 수란?',
                      '사용자가 지도 탭에서 이 매장의 마커를 눌러본 횟수예요.\n'
                          '매장에 대한 관심도를 가늠할 수 있는 지표예요.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatTile(
              label: '오늘 페이지 방문수',
              value: _todayDetailViews == null ? '-' : '$_todayDetailViews회',
              trailing: _infoIcon(
                '페이지 방문수란?',
                '사용자가 이 매장의 상세페이지를 열어본 횟수예요.\n'
                    '홈, 지도, 검색 등 어디에서 들어왔든 상세페이지를 연 경우에만 집계돼요.',
              ),
              wide: true,
            ),

            const SizedBox(height: 20),

            const Text(
              '누적',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: '누적 제보수',
                    value: '${restaurant.totalReports}건',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: '누적 즐겨찾기 수',
                    value: _bookmarkCount == null ? '-' : '$_bookmarkCount명',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: '누적 지도 클릭 수',
                    value: _totalMapClicks == null ? '-' : '$_totalMapClicks회',
                    trailing: _infoIcon(
                      '지도 클릭 수란?',
                      '사용자가 지도 탭에서 이 매장의 마커를 눌러본 횟수예요.\n'
                          '매장에 대한 관심도를 가늠할 수 있는 지표예요.',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: '누적 검색수',
                    value: _totalSearchClicks == null ? '-' : '$_totalSearchClicks회',
                    trailing: _infoIcon(
                      '누적 검색수란?',
                      '사용자가 홈 또는 지도에서 검색해 이 매장을 찾은 횟수예요.\n'
                          '검색 결과에서 매장을 선택했을 때 집계돼요.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatTile(
              label: '누적 페이지 방문수',
              value: _totalDetailViews == null ? '-' : '$_totalDetailViews회',
              trailing: _infoIcon(
                '페이지 방문수란?',
                '사용자가 이 매장의 상세페이지를 열어본 횟수예요.\n'
                    '홈, 지도, 검색 등 어디에서 들어왔든 상세페이지를 연 경우에만 집계돼요.',
              ),
              wide: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoIcon(String title, String description) {
    return GestureDetector(
      onTap: () => _showInfoDialog(title, description),
      child: const Icon(Icons.info_outline, size: 15, color: Color(0xFF9CA3AF)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool wide;
  final Widget? trailing;

  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.wide = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: valueColor ?? const Color(0xFF000000),
            ),
          ),
        ],
      ),
    );
  }
}
