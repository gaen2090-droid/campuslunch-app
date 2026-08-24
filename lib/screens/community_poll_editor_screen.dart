import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// 투표 옵션 작성 전용 화면 (에브리타임 방식 — 본문 작성 화면과 분리).
/// 옵션 목록(List<String>)을 로컬 상태로만 다루고, 완료 시 그 목록을 pop으로
/// 돌려준다. 실제 서버 전송은 게시글이 실제로 게시되는 시점(본문 화면의
/// "게시하기")에 이뤄진다 — 이 화면 단계에서는 아직 아무것도 저장되지 않는다.
class CommunityPollEditorScreen extends StatefulWidget {
  final List<String>? initialOptions;

  const CommunityPollEditorScreen({super.key, this.initialOptions});

  static Future<List<String>?> show(
    BuildContext context, {
    List<String>? initialOptions,
  }) {
    return Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => CommunityPollEditorScreen(initialOptions: initialOptions),
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

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOptions;
    final seed = (initial != null && initial.length >= _minOptions)
        ? initial
        : const ['', ''];
    _controllers = seed.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_controllers.length >= _maxOptions) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_controllers.length <= _minOptions) return;
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  void _deletePoll() {
    Navigator.pop(context, <String>[]);
  }

  void _complete() {
    final options = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (options.length < _minOptions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('옵션을 최소 $_minOptions개 입력해주세요.')),
      );
      return;
    }
    Navigator.pop(context, options);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
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
            onPressed: _deletePoll,
            child: const Text(
              '투표 삭제',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  const Text(
                    '옵션은 2~5개까지 만들 수 있어요. 게시 후에는 수정할 수 없어요.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _controllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[i],
                              maxLength: _maxLabelLength,
                              decoration: InputDecoration(
                                hintText: '옵션 ${i + 1}',
                                counterText: '',
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
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
                    OutlinedButton.icon(
                      onPressed: _addOption,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF000000),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('옵션 추가'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: GestureDetector(
                onTap: _complete,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryCta,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
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
