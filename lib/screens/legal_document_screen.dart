import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 약관·정책 전문 화면 (마크다운 에셋)
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late Future<String> _content;

  @override
  void initState() {
    super.initState();
    _content = rootBundle.loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF000000)),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                '문서를 불러오지 못했어요.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: _LegalMarkdownBody(text: snapshot.data!),
          );
        },
      ),
    );
  }
}

class _LegalMarkdownBody extends StatelessWidget {
  const _LegalMarkdownBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      if (line == '---') {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: Color(0xFFE5E7EB)),
        ));
        continue;
      }
      if (line.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            _stripInline(line.substring(2)),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF000000),
              height: 1.35,
            ),
          ),
        ));
        continue;
      }
      if (line.startsWith('## ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            _stripInline(line.substring(3)),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF000000),
              height: 1.4,
            ),
          ),
        ));
        continue;
      }
      if (line.startsWith('### ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            _stripInline(line.substring(4)),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
              height: 1.45,
            ),
          ),
        ));
        continue;
      }
      if (line.startsWith('> ')) {
        children.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            _stripInline(line.substring(2)),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.55,
            ),
          ),
        ));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 12, height: 1.55)),
              Expanded(
                child: Text(
                  _stripInline(line.substring(2)),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }
      if (line.startsWith('|')) {
        final cells = line
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.every((c) => c.replaceAll('-', '').replaceAll(':', '').isEmpty)) {
          continue;
        }
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            cells.join(' · '),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ));
        continue;
      }
      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            _stripInline(line),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF374151),
              height: 1.55,
            ),
          ),
        ));
        continue;
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          _stripInline(line),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF374151),
            height: 1.55,
          ),
        ),
      ));
    }
    return SelectableRegion(
      focusNode: FocusNode(),
      selectionControls: materialTextSelectionControls,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static String _stripInline(String input) {
    return input
        .replaceAll('**', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1');
  }
}
