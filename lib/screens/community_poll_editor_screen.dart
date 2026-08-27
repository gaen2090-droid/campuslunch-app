import 'package:flutter/material.dart';

/// 투표 항목 작성 전용 화면 (에브리타임 방식 — 본문 작성 화면과 분리).
/// 항목 목록 + 복수 선택 허용 여부를 로컬 상태로만 다루고, 완료 시 그 값을
/// pop으로 돌려준다. 실제 서버 전송은 게시글이 실제로 게시되는 시점(본문
/// 화면의 "게시하기")에 이뤄진다 — 이 화면 단계에서는 아직 아무것도 저장되지
/// 않는다.
class CommunityPollDraft {
  final List<String> options;
  final bool allowMultiple;
  const CommunityPollDraft({required this.options, required this.allowMultiple});
}

class CommunityPollEditorScreen extends StatefulWidget {
  final CommunityPollDraft? initialDraft;

  const CommunityPollEditorScreen({super.key, this.initialDraft});

  static Future<CommunityPollDraft?> show(
    BuildContext context, {
    CommunityPollDraft? initialDraft,
  }) {
    return Navigator.of(context).push<CommunityPollDraft>(
      MaterialPageRoute(
        builder: (_) => CommunityPollEditorScreen(initialDraft: initialDraft),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<CommunityPollEditorScreen> createState() => _CommunityPollEditorScreenState();
}

class _CommunityPollEditorScreenState extends State<CommunityPollEditorScreen> {
  static const _maxOptions = 5;
  static const _minOptions = 2;
  static const _maxLabelLength = 40;

  late final List<TextEditingController> _controllers;
  late bool _allowMultiple;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDraft;
    final seed = (initial != null && initial.options.length >= _minOptions)
        ? initial.options
        : const ['', ''];
    _controllers = seed.map((s) => TextEditingController(text: s)).toList();
    _allowMultiple = initial?.allowMultiple ?? false;
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _canComplete =>
      _controllers.where((c) => c.text.trim().isNotEmpty).length >= _minOptions;

  void _addOption() {
    if (_controllers.length >= _maxOptions) return;
    final c = TextEditingController()..addListener(_onChanged);
    setState(() => _controllers.add(c));
  }

  void _removeOption(int index) {
    if (_controllers.length <= _minOptions) return;
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  void _complete() {
    final options = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (options.length < _minOptions) return;
    Navigator.pop(
      context,
      CommunityPollDraft(options: options, allowMultiple: _allowMultiple),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '투표 만들기',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _canComplete ? _complete : null,
            child: Text(
              '완료',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _canComplete ? const Color(0xFF26BC7D) : const Color(0xFFD1D5DB),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _controllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[i],
                              maxLength: _maxLabelLength,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                color: Color(0xFF000000),
                              ),
                              decoration: InputDecoration(
                                hintText: '항목 입력',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF9CA3AF),
                                ),
                                counterText: '',
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          if (_controllers.length > _minOptions) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removeOption(i),
                              child: const Icon(Icons.remove_circle_outline,
                                  size: 22, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_controllers.length < _maxOptions)
                    GestureDetector(
                      onTap: _addOption,
                      child: DottedBorderBox(
                        child: SizedBox(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add, size: 18, color: Color(0xFF9CA3AF)),
                              SizedBox(width: 6),
                              Text(
                                '항목 추가',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9CA3AF),
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
            Container(height: 8, color: const Color(0xFFF9FAFB)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '복수 선택 허용',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  Switch(
                    value: _allowMultiple,
                    onChanged: (v) => setState(() => _allowMultiple = v),
                    activeThumbColor: const Color(0xFF26BC7D),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 항목 추가 버튼의 점선 테두리 (참고 캡처의 dashed box 재현).
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dashWidth = 5.0;
        const dashGap = 4.0;
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }
    canvas.drawPath(
      dashPath,
      Paint()
        ..color = const Color(0xFFD1D5DB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
