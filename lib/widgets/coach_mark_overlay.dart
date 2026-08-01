import 'package:flutter/material.dart';
import '../models/coach_mark_step.dart';

/// 홈 화면 첫 진입 시 주요 기능을 하나씩 스포트라이트로 안내 (최대 4스텝)
/// 대상 위젯이 화면에 없으면(리스트 비어있음 등) 해당 스텝은 자동 건너뜀.
class CoachMarkOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onFinish;

  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _index = 0;
  Rect? _rect;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  Rect? _rectForKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  /// 스텝의 후보 key들 중 실제로 마운트된(레이아웃된) 첫 번째를 찾는다.
  /// ListView(children:)는 전체 자식을 빌드하므로 뷰포트 밖이어도 대개 context는
  /// 존재하지만(스크롤해야 화면에 보임), 위치는 화면 밖일 수 있다.
  GlobalKey? _targetKey(CoachMarkStep step) {
    for (final key in step.targetKeys) {
      if (key.currentContext != null) return key;
    }
    return null;
  }

  /// 다른 서브트리(홈 화면)의 레이아웃 결과를 읽는 작업은 이번 프레임이 완전히
  /// 끝난 뒤(post-frame)에만 수행한다. build() 도중 findRenderObject()를 호출하면
  /// 아직 레이아웃/마운트가 끝나지 않은 element를 참조해 프레임워크 어설션이 날 수 있다.
  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted) return;

      for (var i = _index; i < widget.steps.length; i++) {
        final key = _targetKey(widget.steps[i]);
        if (key == null) continue;

        // 대상이 스크롤 뷰포트 밖에 있을 수 있으니 먼저 보이는 위치까지 스크롤한다.
        // 지도 탭 아이콘처럼 스크롤 가능한 조상이 없는 대상은 그냥 건너뛴다.
        if (Scrollable.maybeOf(key.currentContext!) != null) {
          await Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: 0.2,
          );
          if (!mounted) return;
        }

        final rect = _rectForKey(key);
        if (rect == null) continue;
        setState(() {
          _index = i;
          _rect = rect;
        });
        return;
      }

      // 남은 스텝 중 화면에 있는 대상이 하나도 없으면 종료
      widget.onFinish();
    });
  }

  void _advance() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinish();
      return;
    }
    setState(() {
      _index++;
      _rect = null;
    });
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    if (rect == null) return const SizedBox.shrink();
    return _StepView(
      step: widget.steps[_index],
      rect: rect,
      stepNumber: _index + 1,
      totalSteps: widget.steps.length,
      onTap: _advance,
      onSkip: widget.onFinish,
    );
  }
}

class _StepView extends StatelessWidget {
  final CoachMarkStep step;
  final Rect rect;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onTap;
  final VoidCallback onSkip;

  const _StepView({
    required this.step,
    required this.rect,
    required this.stepNumber,
    required this.totalSteps,
    required this.onTap,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    const padding = 8.0;
    const edgeMargin = 16.0;
    final rawHoleRect = Rect.fromLTRB(
      rect.left - padding,
      rect.top - padding,
      rect.right + padding,
      rect.bottom + padding,
    );
    // 대상 위젯이 화면 폭을 넘어가도(가로 스크롤 등) 강조 테두리는 항상 화면 안에 보이도록 clamp
    final clampedLeft = rawHoleRect.left.clamp(edgeMargin, screen.width - edgeMargin);
    final clampedRight = rawHoleRect.right.clamp(edgeMargin, screen.width - edgeMargin);
    final holeRect = Rect.fromLTRB(
      clampedLeft,
      rawHoleRect.top,
      clampedRight > clampedLeft ? clampedRight : clampedLeft + edgeMargin,
      rawHoleRect.bottom,
    );

    final showBelow = holeRect.bottom + 160 < screen.height;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            // 어두운 배경 + 대상만 뚫기
            CustomPaint(
              size: screen,
              painter: _SpotlightPainter(
                hole: holeRect,
                circle: step.circleShape,
              ),
            ),
            // 대상 테두리 강조
            Positioned(
              left: holeRect.left,
              top: holeRect.top,
              width: holeRect.width,
              height: holeRect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: step.circleShape ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: step.circleShape ? null : BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ),
            // 말풍선
            Positioned(
              left: 24,
              right: 24,
              top: showBelow ? holeRect.bottom + 16 : null,
              bottom: showBelow ? null : screen.height - holeRect.top + 16,
              child: IgnorePointer(
                ignoring: true,
                child: _Bubble(
                  title: step.title,
                  subtitle: step.subtitle,
                  stepNumber: stepNumber,
                  totalSteps: totalSteps,
                ),
              ),
            ),
            // 건너뛰기
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: GestureDetector(
                onTap: onSkip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _Bubble extends StatelessWidget {
  final String title;
  final String subtitle;
  final int stepNumber;
  final int totalSteps;

  const _Bubble({
    required this.title,
    required this.subtitle,
    required this.stepNumber,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$stepNumber/$totalSteps',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect hole;
  final bool circle;

  const _SpotlightPainter({required this.hole, required this.circle});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = circle
        ? (Path()..addOval(hole))
        : (Path()..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16))));
    final combined = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(combined, Paint()..color = Colors.black.withAlpha(170));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.circle != circle;
}
