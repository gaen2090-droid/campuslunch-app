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
    final lines = text.split('\n');
    var i = 0;
    while (i < lines.length) {
      final raw = lines[i];
      final line = raw.trimRight();
      if (line.startsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trimRight().startsWith('|')) {
          tableLines.add(lines[i].trimRight());
          i++;
        }
        children.add(_buildTable(tableLines));
        continue;
      }
      i++;
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

  static List<String> _splitRow(String line) {
    var cells = line.split('|').map((c) => c.trim()).toList();
    if (cells.isNotEmpty && cells.first.isEmpty) cells = cells.sublist(1);
    if (cells.isNotEmpty && cells.last.isEmpty) {
      cells = cells.sublist(0, cells.length - 1);
    }
    return cells;
  }

  static bool _isSeparatorRow(List<String> cells) {
    return cells.isNotEmpty &&
        cells.every((c) => c.replaceAll('-', '').replaceAll(':', '').isEmpty);
  }

  Widget _buildTable(List<String> tableLines) {
    final rows = tableLines
        .map(_splitRow)
        .where((cells) => !_isSeparatorRow(cells))
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final columnCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    // 첫 컬럼은 항목명이라 짧게, 나머지는 넓게 배분해 화면 폭 안에서 줄바꿈되게 함
    final columnWidths = <int, TableColumnWidth>{
      0: const FlexColumnWidth(1),
      for (var c = 1; c < columnCount; c++) c: const FlexColumnWidth(2),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFE5E7EB)),
        columnWidths: columnWidths,
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: BoxDecoration(
                color: r == 0 ? const Color(0xFFF9FAFB) : Colors.white,
              ),
              children: [
                for (var c = 0; c < columnCount; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(
                      c < rows[r].length ? _stripInline(rows[r][c]) : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: r == 0
                            ? const Color(0xFF111827)
                            : const Color(0xFF374151),
                        fontWeight:
                            r == 0 ? FontWeight.w700 : FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
        ],
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
