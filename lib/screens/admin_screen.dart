import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_metrics.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';

// ── Mock data ──────────────────────────────────────────────────────────────
const _mau = 1843;
const _clickRate = 68.4;
const _pushOpenRate = 41.2;

const _topReporters = [
  ('앙대딸기2391', 23),
  ('앙대망고4782', 18),
  ('앙대키위8104', 15),
];

const _rankEmoji = ['🥇', '🥈', '🥉'];

final _dauWeek = [98, 112, 105, 134, 127, 89, 103];

const _mauMonthly = [1240, 1380, 1520, 1690, 1780, 1843];
const _months6 = ['1월', '2월', '3월', '4월', '5월', '6월'];

final _clickWeekly = [62.1, 65.3, 70.2, 68.4, 71.0, 59.8, 66.7];
final _pushWeekly = [38.2, 40.1, 43.5, 41.2, 44.8, 37.9, 42.3];

final _weekDates = List.generate(7, (i) {
  final d = DateTime.now().subtract(Duration(days: 6 - i));
  return '${d.month}/${d.day}';
});

const _regions = ['학식', '정문', '중문', '후문'];
const _cuisines = ['학식', '한식', '중식', '일식', '양식', '아시아', '분식', '카페'];
const _areaByRegion = {
  '학식': '학생회관',
  '정문': '정문 근처',
  '중문': '중문 근처',
  '후문': '후문 골목',
};

int _totalReports(Restaurant r) =>
    r.reports.values.fold(0, (s, v) => s + v);

// ── Admin screen ────────────────────────────────────────────────────────────
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _tab = 'metrics';
  String? _detail;
  bool _showDau = false;
  bool _showExport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final restaurants = provider.restaurants;
    final metrics = provider.metrics;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관리자',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '대시보드',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.72,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showExport = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF16A34A)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_outlined,
                                  size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 6),
                              Text(
                                '지표 내보내기',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => provider.logout(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.logout,
                                  size: 14, color: Color(0xFF9CA3AF)),
                              SizedBox(width: 6),
                              Text(
                                '로그아웃',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab pills
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      _TabPill(
                        label: '핵심 지표',
                        active: _tab == 'metrics',
                        onTap: () => setState(() => _tab = 'metrics'),
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: '매장 관리',
                        active: _tab == 'restaurants',
                        onTap: () => setState(() => _tab = 'restaurants'),
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: '인기 관리',
                        active: _tab == 'popularity',
                        onTap: () => setState(() => _tab = 'popularity'),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        24, 4, 24, MediaQuery.of(context).padding.bottom + 40),
                    child: _tab == 'metrics'
                        ? _MetricsTab(
                            restaurants: restaurants,
                            metrics: metrics,
                            onDetail: (key) => setState(() => _detail = key),
                            onDauDetail: () => setState(() => _showDau = true),
                          )
                        : _tab == 'restaurants'
                            ? _RestaurantsTab(restaurants: restaurants)
                            : _PopularityTab(restaurants: restaurants),
                  ),
                ),
              ],
            ),
          ),

          // DAU detail sheet
          if (_showDau)
            _DauDetailSheet(onClose: () => setState(() => _showDau = false)),

          // Detail sheet
          if (_detail != null)
            _DetailSheet(
              detailKey: _detail!,
              restaurants: context.read<AppProvider>().restaurants,
              metrics: context.read<AppProvider>().metrics,
              onClose: () => setState(() => _detail = null),
            ),

          // Export sheet
          if (_showExport)
            _ExportSheet(
              onClose: () => setState(() => _showExport = false),
              restaurants: restaurants,
            ),
        ],
      ),
    );
  }
}

// ── Tab pill ─────────────────────────────────────────────────────────────
class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabPill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF111827) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

// ── Metric card ───────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color color;

  const _BarChart(
      {required this.data, required this.labels, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 1.0 : data.reduce(max);
    return Column(
      children: [
        SizedBox(
          height: 128,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.asMap().entries.map((e) {
              final frac = maxVal > 0 ? e.value / maxVal : 0.0;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: e.key < data.length - 1 ? 3 : 0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: max(frac * 128, e.value > 0 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: labels.asMap().entries.map((e) {
            return Expanded(
              child: Text(
                e.value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD1D5DB),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Line chart (CustomPainter) ────────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<double> values;
  final List<String> xLabels;
  final Color color;

  const _LineChart(
      {required this.values, required this.xLabels, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(values: values, xLabels: xLabels, color: color),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> xLabels;
  final Color color;

  const _LineChartPainter(
      {required this.values, required this.xLabels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    const padTop = 8.0;
    const padBottom = 22.0;
    const padLeft = 6.0;
    const padRight = 6.0;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    final minV = values.reduce(min).toDouble();
    final maxV = values.reduce(max).toDouble();
    final range = (maxV - minV).clamp(1.0, double.infinity);

    final pts = values.asMap().entries.map((e) {
      final x = padLeft + (e.key / (values.length - 1)) * chartW;
      final y = padTop + chartH - ((e.value - minV) / range) * chartH;
      return Offset(x, y);
    }).toList();

    // Build smooth bezier path
    final linePath = Path();
    linePath.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final mx = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(mx, prev.dy, mx, curr.dy, curr.dx, curr.dy);
    }

    // Area fill
    final areaPath = Path.from(linePath)
      ..lineTo(pts.last.dx, padTop + chartH)
      ..lineTo(pts.first.dx, padTop + chartH)
      ..close();

    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withAlpha(46), color.withAlpha(0)],
      ).createShader(Rect.fromLTWH(0, padTop, size.width, chartH))
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, gradPaint);

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Last point dot
    final last = pts.last;
    canvas.drawCircle(last, 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(
        last,
        3.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // X labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < xLabels.length; i++) {
      if (xLabels[i].isEmpty) continue;
      final x = padLeft + (i / (values.length - 1)) * chartW;
      tp.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Color(0xFFD1D5DB),
        ),
      );
      tp.layout();
      tp.paint(canvas,
          Offset(x - tp.width / 2, size.height - tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Metrics tab ───────────────────────────────────────────────────────────
class _MetricsTab extends StatelessWidget {
  final List<Restaurant> restaurants;
  final DashboardMetrics metrics;
  final ValueChanged<String> onDetail;
  final VoidCallback onDauDetail;

  const _MetricsTab({
    required this.restaurants,
    required this.metrics,
    required this.onDetail,
    required this.onDauDetail,
  });

  @override
  Widget build(BuildContext context) {
    final todayReports = metrics.todayReports > 0
        ? metrics.todayReports
        : restaurants.fold(0, (s, r) => s + _totalReports(r));
    final weekTotal = metrics.weekTotal > 0
        ? metrics.weekTotal
        : restaurants.fold(0, (s, r) => s + _totalReports(r));
    final weekAvg = restaurants.isEmpty
        ? 0.0
        : (weekTotal / restaurants.length * 10).round() / 10;
    final dauData = metrics.dailyReports.any((v) => v > 0)
        ? metrics.dailyReports
        : _dauWeek;
    final todayDau = dauData.last;

    final sorted = [...restaurants]
      ..sort((a, b) => _totalReports(b) - _totalReports(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2x3 metric grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.6,
          children: [
            _MetricCard(
              label: 'DAU',
              value: '$todayDau',
              unit: '명',
              onTap: onDauDetail,
            ),
            _MetricCard(
              label: 'MAU',
              value: _mau.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (m) => '${m[1]},'),
              unit: '명',
              onTap: () => onDetail('mau'),
            ),
            _MetricCard(
              label: '오늘 누적 제보',
              value: '$todayReports',
              unit: '건',
              onTap: () => onDetail('reports'),
            ),
            _MetricCard(
              label: '최근 7일 누적 제보',
              value: '$weekTotal',
              unit: '건',
              onTap: () => onDetail('weekAvg'),
            ),
            _MetricCard(
              label: '추천 배너 클릭률',
              value: '$_clickRate',
              unit: '%',
              onTap: () => onDetail('clickRate'),
            ),
            _MetricCard(
              label: '푸시 오픈율',
              value: '$_pushOpenRate',
              unit: '%',
              onTap: () => onDetail('pushOpenRate'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Top 3 restaurants
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘 제보 많은 매장 Top 3',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 12),
              ...sorted.take(3).toList().asMap().entries.map((e) => Padding(
                    padding: EdgeInsets.only(
                        bottom: e.key < 2 ? 12 : 0),
                    child: Row(
                      children: [
                        Text(_rankEmoji[e.key],
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${_totalReports(e.value)}건',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Text(
                '누적 제보 기준',
                style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Top reporters
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘 제보 많은 유저 Top 3',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 12),
              if (metrics.topReporters.isEmpty)
                const Text('아직 제보 데이터가 없어요',
                    style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)))
              else
                ...metrics.topReporters.asMap().entries.map((e) => Padding(
                      padding: EdgeInsets.only(bottom: e.key < 2 ? 12 : 0),
                      child: Row(
                        children: [
                          Text(_rankEmoji[e.key],
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.value.$1.length > 8
                                  ? '${e.value.$1.substring(0, 8)}...'
                                  : e.value.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Text(
                            '${e.value.$2}건',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Owner registration status
        GestureDetector(
          onTap: () => onDetail('ownerStatus'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '오너 등록 현황',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '0',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '/ ${restaurants.length} 매장',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'DAU · MAU · 클릭률은 백엔드 연동 후 실시간 반영돼요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
        ),
      ],
    );
  }
}

// ── Algorithm toggle card ─────────────────────────────────────────────────
class _AlgorithmToggleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isOn = provider.useAlgorithmRanking;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('인기도 알고리즘',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827))),
                    SizedBox(height: 4),
                    Text('최근 1주 혼잡도 지속시간 기반 자동 측정',
                        style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => provider.toggleAlgorithmRanking(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isOn ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 24, height: 24,
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Popularity tab ───────────────────────────────────────────────────────
class _PopularityTab extends StatelessWidget {
  final List<Restaurant> restaurants;
  const _PopularityTab({required this.restaurants});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final useAlgo = provider.useAlgorithmRanking;

    final sorted = useAlgo
        ? ([...restaurants]..sort((a, b) {
            final aScore = a.popularityScore > 0 ? a.popularityScore : a.totalReports;
            final bScore = b.popularityScore > 0 ? b.popularityScore : b.totalReports;
            return bScore.compareTo(aScore);
          }))
        : ([...restaurants]..sort((a, b) {
            if (a.manualRank == 0 && b.manualRank == 0) return 0;
            if (a.manualRank == 0) return 1;
            if (b.manualRank == 0) return -1;
            return a.manualRank.compareTo(b.manualRank);
          }));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlgorithmToggleCard(),
        const SizedBox(height: 20),
        const Text('인기 순위',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF))),
        const SizedBox(height: 4),
        Text(
          useAlgo ? '알고리즘이 자동으로 산정한 순위예요' : '카드를 드래그해서 순서를 바꿔보세요',
          style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
        ),
        const SizedBox(height: 12),
        if (useAlgo)
          ...sorted.asMap().entries.map((entry) {
            final idx = entry.key;
            final r = entry.value;
            return Padding(
              key: ValueKey(r.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    _RankBadge(rank: idx + 1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827))),
                          Text('${r.area} · ${r.category}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final ids = sorted.map((e) => e.id).toList();
              final item = ids.removeAt(oldIndex);
              ids.insert(newIndex, item);
              provider.setManualRanks(ids);
            },
            children: sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value;
              return Padding(
                key: ValueKey(r.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: ReorderableDragStartListener(
                  index: idx,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        _RankBadge(rank: idx + 1),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF111827))),
                              Text('${r.area} · ${r.category}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        const Icon(Icons.drag_handle,
                            size: 20, color: Color(0xFFD1D5DB)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ── Rank badge ────────────────────────────────────────────────────────────
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFF16A34A),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Restaurants tab ───────────────────────────────────────────────────────
class _RestaurantsTab extends StatefulWidget {
  final List<Restaurant> restaurants;

  const _RestaurantsTab({required this.restaurants});

  @override
  State<_RestaurantsTab> createState() => _RestaurantsTabState();
}

class _RestaurantsTabState extends State<_RestaurantsTab> {
  bool _showAdd = false;
  Restaurant? _editTarget;
  String? _confirmDeleteId;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final sorted = widget.restaurants;

    return Stack(
      children: [
        Column(
          children: [
            // Add button
            GestureDetector(
              onTap: () => setState(() => _showAdd = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 8),
                    Text(
                      '매장 추가',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Restaurant list
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value;
              final isConfirming = _confirmDeleteId == r.id;
              return Padding(
                key: ValueKey(r.id),
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.area} · ${r.category}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('사장님 코드 ',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF))),
                                    if (r.ownerCode.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: const Color(0xFFBBF7D0)),
                                        ),
                                        child: Text(
                                          r.ownerCode,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF16A34A),
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: () => provider.generateOwnerCode(r.id),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF9FAFB),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: const Color(0xFFE5E7EB)),
                                          ),
                                          child: const Text('발급',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF9CA3AF))),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() {
                                  _editTarget = r;
                                  _confirmDeleteId = null;
                                }),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.edit_outlined,
                                      size: 16, color: Color(0xFF6B7280)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _confirmDeleteId =
                                      isConfirming ? null : r.id;
                                }),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF5F5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.delete_outline,
                                      size: 16, color: Color(0xFFF87171)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Delete confirm
                      if (isConfirming) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '정말 삭제할까요?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _confirmDeleteId = null),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '취소',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  provider.deleteRestaurant(r.id);
                                  setState(() => _confirmDeleteId = null);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '삭제',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),

        // Add sheet overlay
        if (_showAdd)
          Positioned.fill(
            child: _AddRestaurantSheet(
              onClose: () => setState(() => _showAdd = false),
              onAdd: (data) {
                provider.addRestaurant(data);
                setState(() => _showAdd = false);
              },
            ),
          ),

        // Edit sheet overlay
        if (_editTarget != null)
          Positioned.fill(
            child: _EditRestaurantSheet(
              restaurant: _editTarget!,
              onClose: () => setState(() => _editTarget = null),
              onSave: (data) {
                provider.editRestaurant(_editTarget!.id, data);
                setState(() => _editTarget = null);
              },
            ),
          ),
      ],
    );
  }
}

// ── Shared sheet base ─────────────────────────────────────────────────────
class _SheetBase extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;

  const _SheetBase(
      {required this.title, required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withAlpha(77),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.close,
                                  size: 16, color: Color(0xFF6B7280)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── DAU detail sheet ──────────────────────────────────────────────────────
class _DauDetailSheet extends StatefulWidget {
  final VoidCallback onClose;

  const _DauDetailSheet({required this.onClose});

  @override
  State<_DauDetailSheet> createState() => _DauDetailSheetState();
}

class _DauDetailSheetState extends State<_DauDetailSheet> {
  List<String> get _weekLabels => List.generate(7, (i) {
        final d = DateTime.now().subtract(Duration(days: 6 - i));
        return '${d.month}/${d.day}';
      });

  @override
  Widget build(BuildContext context) {
    final metrics = context.watch<AppProvider>().metrics;
    final rawVals = metrics.dailyReports.any((v) => v > 0)
        ? metrics.dailyReports
        : _dauWeek;
    final vals = rawVals.map((v) => v.toDouble()).toList();
    final lbls = _weekLabels;
    final current = vals.last;
    final diff = current - vals[vals.length - 2];

    return _SheetBase(
      title: 'DAU (일별 제보 활동)',
      onClose: widget.onClose,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${current.toInt()}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '명',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${diff >= 0 ? '+' : ''}${diff.toInt()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: diff >= 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LineChart(
              values: vals,
              xLabels: lbls,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 12),
            const Text(
              '최근 7일 제보 활동량',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail sheet ──────────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final String detailKey;
  final List<Restaurant> restaurants;
  final DashboardMetrics metrics;
  final VoidCallback onClose;

  const _DetailSheet({
    required this.detailKey,
    required this.restaurants,
    required this.metrics,
    required this.onClose,
  });

  Widget _restaurantBarList(Map<String, int> countById, int total) {
    final data = restaurants.map((r) {
      final cnt = countById[r.id] ?? 0;
      return (r.name, cnt);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final maxV = data.isEmpty ? 1 : data.map((e) => e.$2).reduce(max);
    final avg = restaurants.isEmpty
        ? 0.0
        : (total / restaurants.length * 10).round() / 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('평균',
                  style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
              const SizedBox(width: 8),
              Text('$avg건',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...data.map((e) {
          final frac = maxV > 0 ? e.$2 / maxV : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(e.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(children: [
                            Container(height: 6, color: const Color(0xFFF3F4F6)),
                            FractionallySizedBox(
                              widthFactor: frac,
                              child: Container(height: 6, color: const Color(0xFF16A34A)),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 28,
                        child: Text('${e.$2}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    Widget body = const SizedBox.shrink();

    if (detailKey == 'reports') {
      title = '오늘 매장별 제보 수';
      body = _restaurantBarList(metrics.todayByRestaurant, metrics.todayReports);
    } else if (detailKey == 'weekAvg') {
      title = '최근 7일 매장별 제보 수';
      body = _restaurantBarList(metrics.weekByRestaurant, metrics.weekTotal);
    } else {
      final configs = {
        'mau': ('월간 활성 사용자 추이',
            _mauMonthly.map((v) => v.toDouble()).toList(),
            _months6.toList(),
            const Color(0xFF16A34A)),
        'clickRate': ('추천 배너 클릭률 추이', _clickWeekly, _weekDates,
            const Color(0xFF16A34A)),
        'pushOpenRate': ('푸시 오픈율 추이', _pushWeekly, _weekDates,
            const Color(0xFF16A34A)),
      };

      if (detailKey == 'ownerStatus') {
        title = '오너 등록 현황';
        body = Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              '오너 미등록 매장',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 8),
            ...restaurants.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(r.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            )),
                      ],
                    ),
                  ),
                )),
          ],
        );
      } else if (configs.containsKey(detailKey)) {
        final cfg = configs[detailKey]!;
        title = cfg.$1;
        body = Column(
          children: [
            _BarChart(
              data: cfg.$2,
              labels: cfg.$3,
              color: cfg.$4,
            ),
            const SizedBox(height: 16),
            const Text(
              '백엔드 연동 전 목업 데이터예요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
            ),
          ],
        );
      }
    }

    return _SheetBase(
      title: title,
      onClose: onClose,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: body,
      ),
    );
  }
}

// ── Export sheet ──────────────────────────────────────────────────────────
class _ExportSheet extends StatefulWidget {
  final VoidCallback onClose;
  final List<Restaurant> restaurants;

  const _ExportSheet({required this.onClose, required this.restaurants});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  static const _sheetLabels = [
    '사용자 지표',
    '리텐션',
    '시간대 분석',
    '오너 참여 현황',
    '유저 제보 참여 현황',
    '전환 지표',
    '매장 현황',
  ];

  late Set<String> _selected;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(_sheetLabels);
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 29));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final first = DateTime(2024);
    final last = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF16A34A),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  void _toggle(String label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  String _buildCsv() {
    final buf = StringBuffer();
    final period = '${_fmt(_startDate)} ~ ${_fmt(_endDate)}';
    final rs = widget.restaurants;

    void section(String title, List<List<String>> rows) {
      buf.writeln('[$title] 기간: $period');
      for (final row in rows) {
        buf.writeln(row.map((c) => '"$c"').join(','));
      }
      buf.writeln();
    }

    if (_selected.contains('사용자 지표')) {
      section('사용자 지표', [
        ['항목', '값'],
        ['DAU', '$_mau명 (오늘 ${_dauWeek.last}명)'],
        ['MAU', '$_mau명'],
        ['추천 배너 클릭률', '$_clickRate%'],
        ['푸시 오픈율', '$_pushOpenRate%'],
      ]);
    }
    if (_selected.contains('매장 현황')) {
      section('매장 현황', [
        ['매장명', '구역', '카테고리', '현재 상태', '누적 제보', '영업시간'],
        ...rs.map((r) => [
          r.name, r.area, r.category, r.status,
          '${r.totalReports}건', r.hours,
        ]),
      ]);
    }
    if (_selected.contains('유저 제보 참여 현황')) {
      section('유저 제보 참여 현황', [
        ['매장명', '여유로움', '약간혼잡', '자리없음', '합계'],
        ...rs.map((r) => [
          r.name,
          '${r.reports['여유로움'] ?? 0}',
          '${r.reports['약간혼잡'] ?? 0}',
          '${r.reports['자리없음'] ?? 0}',
          '${r.totalReports}',
        ]),
      ]);
    }
    if (_selected.contains('오너 참여 현황')) {
      section('오너 참여 현황', [
        ['매장명', '오너 등록'],
        ...rs.map((r) => [r.name, '미등록']),
      ]);
    }
    for (final label in ['리텐션', '시간대 분석', '전환 지표']) {
      if (_selected.contains(label)) {
        section(label, [['※ 백엔드 연동 후 실데이터로 교체 예정']]);
      }
    }
    return buf.toString();
  }

  void _export() {
    final csv = _buildCsv();
    // UTF-8 BOM 추가 (Excel에서 한글 깨짐 방지)
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final filename = 'campuslunch_${_fmt(_startDate)}_${_fmt(_endDate)}.csv';
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == _sheetLabels.length;

    return _SheetBase(
      title: '지표 내보내기',
      onClose: widget.onClose,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '기간',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isStart: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 8),
                          Text(
                            _fmt(_startDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('~', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF))),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isStart: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 8),
                          Text(
                            _fmt(_endDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '포함 시트',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _selected = allSelected
                        ? {}
                        : Set.from(_sheetLabels);
                  }),
                  child: Text(
                    allSelected ? '전체 해제' : '전체 선택',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._sheetLabels.map((label) {
              final checked = _selected.contains(label);
              return GestureDetector(
                onTap: () => _toggle(label),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: checked
                              ? const Color(0xFF16A34A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: checked
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                        ),
                        child: checked
                            ? const Icon(Icons.check,
                                size: 10, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: checked
                              ? const Color(0xFF374151)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _selected.isEmpty ? null : _export,
              child: Opacity(
                opacity: _selected.isEmpty ? 0.4 : 1.0,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_outlined,
                          size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'CSV로 내보내기 (.csv)',
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
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add restaurant sheet ───────────────────────────────────────────────────
class _AddRestaurantSheet extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onAdd;

  const _AddRestaurantSheet({required this.onClose, required this.onAdd});

  @override
  State<_AddRestaurantSheet> createState() => _AddRestaurantSheetState();
}

class _AddRestaurantSheetState extends State<_AddRestaurantSheet> {
  final _nameCtrl = TextEditingController();
  String _region = '정문';
  String _cuisine = '한식';
  final List<_TimeRange> _times = [_TimeRange('11:00', '21:00')];
  final List<_MenuEntry> _menu = [_MenuEntry()];
  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  bool _uploading = false;
  String _error = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.first.bytes == null) return;
    setState(() {
      _imageBytes = result.files.first.bytes;
      _imageExt = result.files.first.extension ?? 'jpg';
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = '매장명을 입력해주세요.');
      return;
    }
    setState(() => _uploading = true);
    String imageUrl = '';
    if (_imageBytes != null) {
      imageUrl = await context.read<AppProvider>()
              .uploadRestaurantImage(_imageBytes!, _imageExt) ??
          '';
    }
    final hours = _times.map((t) => '${t.from} - ${t.to}').join(', ');
    final validMenu = _menu
        .where((m) => m.name.isNotEmpty)
        .map((m) => {'name': m.name, 'price': int.tryParse(m.price) ?? 0})
        .toList();
    widget.onAdd({
      'name': _nameCtrl.text.trim(),
      'area': _region,
      'category': _cuisine,
      'address': _areaByRegion[_region] ?? _region,
      'hours': hours,
      'menu': validMenu,
      if (imageUrl.isNotEmpty) 'image_url': imageUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '매장 추가',
      onClose: widget.onClose,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel('이미지'),
            _ImagePickerField(pickedBytes: _imageBytes, onTap: _pickImage),
            const SizedBox(height: 12),
            _FieldLabel('매장명 *'),
            _InputField(controller: _nameCtrl, hint: 'ex. 정문 돈까스'),
            const SizedBox(height: 12),
            _FieldLabel('지역 *'),
            _SelectField<String>(
              value: _region,
              items: _regions,
              onChanged: (v) => setState(() => _region = v),
            ),
            const SizedBox(height: 12),
            _FieldLabel('카테고리 *'),
            _SelectField<String>(
              value: _cuisine,
              items: _cuisines,
              onChanged: (v) => setState(() => _cuisine = v),
            ),
            const SizedBox(height: 12),
            _FieldLabel('영업시간 *'),
            ..._times.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                          child: _TimeField(
                        value: e.value.from,
                        onChange: (v) =>
                            setState(() => _times[e.key].from = v),
                      )),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF9CA3AF))),
                      ),
                      Expanded(
                          child: _TimeField(
                        value: e.value.to,
                        onChange: (v) =>
                            setState(() => _times[e.key].to = v),
                      )),
                      if (_times.length > 1) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _times.removeAt(e.key)),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
            GestureDetector(
              onTap: () => setState(
                  () => _times.add(_TimeRange('11:00', '21:00'))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      style: BorderStyle.solid),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 6),
                    Text('시간대 추가',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FieldLabel('메뉴'),
            ..._menu.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) =>
                              setState(() => _menu[e.key].name = v),
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF111827)),
                          decoration: _inputDecoration('메뉴명'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          onChanged: (v) => setState(
                              () => _menu[e.key].price =
                                  v.replaceAll(RegExp(r'\D'), '')),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF111827)),
                          decoration:
                              _inputDecoration('0').copyWith(suffixText: '원'),
                        ),
                      ),
                      if (_menu.length > 1) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _menu.removeAt(e.key)),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
            GestureDetector(
              onTap: () => setState(() => _menu.add(_MenuEntry())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 6),
                    Text('메뉴 추가',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444))),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _uploading ? null : _submit,
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _uploading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('추가하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit restaurant sheet ─────────────────────────────────────────────────
class _EditRestaurantSheet extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _EditRestaurantSheet({
    required this.restaurant,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<_EditRestaurantSheet> createState() => _EditRestaurantSheetState();
}

class _EditRestaurantSheetState extends State<_EditRestaurantSheet> {
  late TextEditingController _nameCtrl;
  late String _region;
  late String _cuisine;
  late List<_TimeRange> _times;
  late List<_MenuEntry> _menu;
  String _error = '';
  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _nameCtrl = TextEditingController(text: r.name);
    _region = _regions.contains(r.area) ? r.area : '정문';
    _cuisine = _cuisines.contains(r.category) ? r.category : '한식';
    _times = _parseTimeRanges(r.hours);
    _menu = r.menu.isNotEmpty
        ? r.menu.map((m) => _MenuEntry()
          ..name = m.name
          ..price = '${m.price}').toList()
        : [_MenuEntry()];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<_TimeRange> _parseTimeRanges(String hours) {
    if (hours.isEmpty) return [_TimeRange('11:00', '21:00')];
    final ranges = hours.split(',').map((s) {
      final parts = s.trim().split(' - ');
      return _TimeRange(
        parts.isNotEmpty ? parts[0].trim() : '11:00',
        parts.length > 1 ? parts[1].trim() : '21:00',
      );
    }).toList();
    return ranges.isEmpty ? [_TimeRange('11:00', '21:00')] : ranges;
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.first.bytes == null) return;
    setState(() {
      _imageBytes = result.files.first.bytes;
      _imageExt = result.files.first.extension ?? 'jpg';
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = '매장명을 입력해주세요.');
      return;
    }
    setState(() => _uploading = true);
    String? imageUrl;
    if (_imageBytes != null) {
      imageUrl = await context.read<AppProvider>()
          .uploadRestaurantImage(_imageBytes!, _imageExt);
    }
    final hours = _times.map((t) => '${t.from} - ${t.to}').join(', ');
    final validMenu = _menu
        .where((m) => m.name.isNotEmpty)
        .map((m) => {'name': m.name, 'price': int.tryParse(m.price) ?? 0})
        .toList();
    widget.onSave({
      'name': _nameCtrl.text.trim(),
      'area': _region,
      'category': _cuisine,
      'address': _areaByRegion[_region] ?? _region,
      'hours': hours,
      'menu': validMenu,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '매장 수정',
      onClose: widget.onClose,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel('이미지'),
            _ImagePickerField(
              currentUrl: widget.restaurant.imageUrl,
              pickedBytes: _imageBytes,
              onTap: _pickImage,
            ),
            const SizedBox(height: 12),
            _FieldLabel('매장명 *'),
            _InputField(controller: _nameCtrl, hint: 'ex. 정문 돈까스'),
            const SizedBox(height: 12),
            _FieldLabel('지역 *'),
            _SelectField<String>(
              value: _region,
              items: _regions,
              onChanged: (v) => setState(() => _region = v),
            ),
            const SizedBox(height: 12),
            _FieldLabel('카테고리 *'),
            _SelectField<String>(
              value: _cuisine,
              items: _cuisines,
              onChanged: (v) => setState(() => _cuisine = v),
            ),
            const SizedBox(height: 12),
            _FieldLabel('영업시간 *'),
            ..._times.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                          child: _TimeField(
                        value: e.value.from,
                        onChange: (v) =>
                            setState(() => _times[e.key].from = v),
                      )),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF9CA3AF))),
                      ),
                      Expanded(
                          child: _TimeField(
                        value: e.value.to,
                        onChange: (v) =>
                            setState(() => _times[e.key].to = v),
                      )),
                      if (_times.length > 1) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _times.removeAt(e.key)),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
            GestureDetector(
              onTap: () => setState(
                  () => _times.add(_TimeRange('11:00', '21:00'))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 6),
                    Text('시간대 추가',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FieldLabel('메뉴'),
            ..._menu.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: e.value.name)
                            ..selection = TextSelection.collapsed(
                                offset: e.value.name.length),
                          onChanged: (v) =>
                              setState(() => _menu[e.key].name = v),
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF111827)),
                          decoration: _inputDecoration('메뉴명'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: TextEditingController(text: e.value.price)
                            ..selection = TextSelection.collapsed(
                                offset: e.value.price.length),
                          onChanged: (v) => setState(() =>
                              _menu[e.key].price =
                                  v.replaceAll(RegExp(r'\D'), '')),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF111827)),
                          decoration:
                              _inputDecoration('0').copyWith(suffixText: '원'),
                        ),
                      ),
                      if (_menu.length > 1) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _menu.removeAt(e.key)),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
            GestureDetector(
              onTap: () => setState(() => _menu.add(_MenuEntry())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 6),
                    Text('메뉴 추가',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444))),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _uploading ? null : _submit,
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _uploading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('저장하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image picker widget ───────────────────────────────────────────────────
class _ImagePickerField extends StatelessWidget {
  final String? currentUrl;
  final Uint8List? pickedBytes;
  final VoidCallback onTap;

  const _ImagePickerField({
    this.currentUrl,
    this.pickedBytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = pickedBytes != null || (currentUrl?.isNotEmpty ?? false);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: pickedBytes != null
              ? Image.memory(pickedBytes!, fit: BoxFit.cover)
              : (currentUrl?.isNotEmpty ?? false)
                  ? Image.network(currentUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_photo_alternate_outlined,
              size: 28, color: Color(0xFF9CA3AF)),
          SizedBox(height: 6),
          Text('이미지 추가',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      );
}

// ── Shared form helpers ───────────────────────────────────────────────────
class _TimeRange {
  String from;
  String to;
  _TimeRange(this.from, this.to);
}

class _MenuEntry {
  String name = '';
  String price = '';
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _InputField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
      decoration: _inputDecoration(hint),
    );
  }
}

class _SelectField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;

  const _SelectField(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827)),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text('$item'),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;

  const _TimeField({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    final h = parts.isNotEmpty ? parts[0] : '11';
    final m = parts.length > 1 ? parts[1] : '00';
    final hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
    const mins = ['00', '30'];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: hours.contains(h) ? h : '11',
                isExpanded: true,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
                onChanged: (v) {
                  if (v != null) onChange('$v:$m');
                },
                items: hours
                    .map((hh) => DropdownMenuItem(
                          value: hh,
                          child: Text(hh),
                        ))
                    .toList(),
              ),
            ),
          ),
          const Text(':',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF9CA3AF))),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: mins.contains(m) ? m : '00',
                isExpanded: true,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
                onChanged: (v) {
                  if (v != null) onChange('$h:$v');
                },
                items: mins
                    .map((mm) => DropdownMenuItem(
                          value: mm,
                          child: Text(mm),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle:
        const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
  );
}
