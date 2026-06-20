import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

int _hangulCount(String text) {
  return RegExp(r'[\uAC00-\uD7A3]').allMatches(text).length;
}

int _replacementCount(String text) =>
    RegExp(r'\uFFFD').allMatches(text).length;

int _scoreText(String text) =>
    _hangulCount(text) * 10 - _replacementCount(text) * 100;

Uint8List _stripUtf8Bom(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return Uint8List.sublistView(bytes, 3);
  }
  return bytes;
}

String? _decodeEucKr(Uint8List bytes) {
  try {
    return eucKr.decode(bytes);
  } catch (_) {
    return null;
  }
}

/// CSV 파일 바이트 → 텍스트 (UTF-8 BOM / EUC-KR·CP949 자동 선택)
String decodeCsvTextBytes(Uint8List bytes) {
  final noBom = _stripUtf8Bom(bytes);

  final candidates = <String>[
    utf8.decode(noBom, allowMalformed: true),
    if (_decodeEucKr(bytes) case final eucKrText? when eucKrText.isNotEmpty)
      eucKrText,
  ];

  var best = candidates.first;
  var bestScore = _scoreText(best);
  for (final c in candidates.skip(1)) {
    final score = _scoreText(c);
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best;
}

String decodeCsvTextBytesList(List<int> bytes) =>
    decodeCsvTextBytes(Uint8List.fromList(bytes));
