import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final restaurants = provider.restaurants;

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
                            border: Border.all(color: const Color(0xFFFF6207)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_outlined,
                                  size: 14, color: Color(0xFFFF6207)),
                              SizedBox(width: 6),
                              Text(
                                '지표 내보내기',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF6207),
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
                            onDetail: (key) => setState(() => _detail = key),
                            onDauDetail: () =>
                                setState(() => _showDau = true),
                          )
                        : _RestaurantsTab(restaurants: restaurants),
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
              onClose: () => setState(() => _detail = null),
            ),

          // Export sheet
          if (_showExport)
            _ExportSheet(onClose: () => setState(() => _showExport = false)),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 4),
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
  final ValueChanged<String> onDetail;
  final VoidCallback onDauDetail;

  const _MetricsTab({
    required this.restaurants,
    required this.onDetail,
    required this.onDauDetail,
  });

  @override
  Widget build(BuildContext context) {
    final totalReports =
        restaurants.fold(0, (s, r) => s + _totalReports(r));
    final avgReports = restaurants.isEmpty
        ? 0.0
        : (totalReports / restaurants.length * 10).round() / 10;
    final todayDau = _dauWeek.last;

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
          childAspectRatio: 1.3,
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
              value: '$totalReports',
              unit: '건',
              onTap: () => onDetail('reports'),
            ),
            _MetricCard(
              label: '매장 평균 제보',
              value: '$avgReports',
              unit: '건',
              onTap: () => onDetail('avgReports'),
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
                            color: Color(0xFFFF6207),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Text(
                '누적 제보 기준 · 백엔드 연동 후 일별 집계 반영돼요',
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
              ..._topReporters.toList().asMap().entries.map((e) => Padding(
                    padding: EdgeInsets.only(
                        bottom: e.key < 2 ? 12 : 0),
                    child: Row(
                      children: [
                        Text(_rankEmoji[e.key],
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value.$1,
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
                            color: Color(0xFFFF6207),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Text(
                '백엔드 연동 후 실시간 반영돼요',
                style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
              ),
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
            ...widget.restaurants.map((r) {
              final isConfirming = _confirmDeleteId == r.id;
              return Padding(
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
  String _period = 'week';

  static const _periods = {
    'week': ('1주', [98.0, 112, 105, 134, 127, 89, 103], ['월', '화', '수', '목', '금', '토', '일']),
    'month': ('1개월', [85.0, 88, 90, 92, 89, 95, 98, 102, 99, 108, 112, 107, 115, 118, 112, 120, 118, 125, 122, 127, 120, 128, 125, 130, 127, 122, 118, 125, 127, 103], ['1일', '', '', '', '', '', '', '', '', '', '', '', '', '', '15일', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '30일']),
  };

  @override
  Widget build(BuildContext context) {
    final vals = (_periods[_period] ?? _periods['week']!).$2.map((v) => v.toDouble()).toList();
    final lbls = (_periods[_period] ?? _periods['week']!).$3;
    final current = vals.last;
    final diff = current - vals[vals.length - 2];

    return _SheetBase(
      title: '일간 활성 사용자',
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
            Row(
              children: _periods.keys.map((key) {
                final isActive = _period == key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _period = key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF111827)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _periods[key]!.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _LineChart(
              values: vals,
              xLabels: lbls,
              color: const Color(0xFFFF6207),
            ),
            const SizedBox(height: 12),
            const Text(
              '백엔드 연동 전 목업 데이터예요',
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
  final VoidCallback onClose;

  const _DetailSheet({
    required this.detailKey,
    required this.restaurants,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    String title = '';
    Widget body = const SizedBox.shrink();

    if (detailKey == 'reports' || detailKey == 'avgReports') {
      final sorted = [...restaurants]
        ..sort((a, b) => _totalReports(b) - _totalReports(a));
      final chartData = restaurants.map((r) => _totalReports(r).toDouble()).toList();
      final maxV =
          chartData.isEmpty ? 1.0 : chartData.reduce(max);
      title = detailKey == 'reports' ? '매장별 누적 제보 수' : '매장 평균 제보 수';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BarChart(
            data: chartData,
            labels: restaurants.map((r) => r.emoji).toList(),
            color: const Color(0xFFFF6207),
          ),
          const SizedBox(height: 16),
          ...sorted.map((r) {
            final frac = maxV > 0 ? _totalReports(r) / maxV : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Stack(
                              children: [
                                Container(
                                    height: 6,
                                    color: const Color(0xFFF3F4F6)),
                                FractionallySizedBox(
                                  widthFactor: frac,
                                  child: Container(
                                    height: 6,
                                    color: const Color(0xFFFF6207),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${_totalReports(r)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
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
    } else {
      final configs = {
        'mau': ('월간 활성 사용자 추이',
            _mauMonthly.map((v) => v.toDouble()).toList(),
            _months6.toList(),
            const Color(0xFFFF6207)),
        'clickRate': ('추천 배너 클릭률 추이', _clickWeekly, _weekDates,
            const Color(0xFF6366F1)),
        'pushOpenRate': ('푸시 오픈율 추이', _pushWeekly, _weekDates,
            const Color(0xFF10B981)),
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

  const _ExportSheet({required this.onClose});

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

  @override
  void initState() {
    super.initState();
    _selected = Set.from(_sheetLabels);
  }

  void _toggle(String label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                '최근 30일',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
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
                      color: Color(0xFFFF6207),
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
                              ? const Color(0xFFFF6207)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: checked
                                ? const Color(0xFFFF6207)
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
              onTap: _selected.isEmpty
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            '엑셀 내보내기는 출시 후 지원 예정이에요',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          backgroundColor: const Color(0xFF111827),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      widget.onClose();
                    },
              child: Opacity(
                opacity: _selected.isEmpty ? 0.4 : 1.0,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6207),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_outlined,
                          size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '엑셀로 내보내기 (.xlsx)',
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
  String _error = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = '매장명을 입력해주세요.');
      return;
    }
    final hours =
        _times.map((t) => '${t.from} - ${t.to}').join(', ');
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
              onTap: _submit,
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6207),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '추가하기',
                    style: TextStyle(
                      fontSize: 15,
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

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = '매장명을 입력해주세요.');
      return;
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
              onTap: _submit,
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6207),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '저장하기',
                    style: TextStyle(
                      fontSize: 15,
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
    );
  }
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
        borderSide: const BorderSide(color: Color(0xFFFF6207), width: 1.5)),
  );
}
