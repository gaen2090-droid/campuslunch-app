/// 기프티콘 CSV 파싱 (BOM, 세미콜론/탭 구분, 헤더 별칭 허용)
class GifticonCsvParser {
  static const _headerAliases = {
    'productname': 'product_name',
    'product': 'product_name',
    'imageurl': 'image_url',
    'image': 'image_url',
    'expires': 'expires_at',
    'expire': 'expires_at',
    'expiry': 'expires_at',
    'expiration_date': 'expires_at',
    'expiration': 'expires_at',
    'couponcode': 'coupon_code',
    'coupon': 'coupon_code',
    'code': 'coupon_code',
  };

  static String stripBom(String text) {
    if (text.startsWith('\uFEFF')) return text.substring(1);
    return text;
  }

  static String normalizeHeader(String raw) {
    var h = raw.trim();
    if (h.startsWith('\uFEFF')) h = h.substring(1).trim();
    if (h.length >= 2 && h.startsWith('"') && h.endsWith('"')) {
      h = h.substring(1, h.length - 1).trim();
    }
    h = h.toLowerCase();
    h = h.replaceAll(RegExp(r'[\s\-]+'), '_');
    h = h.replaceAll(RegExp(r'_+'), '_');
    h = h.replaceAll(RegExp(r'^_|_$'), '');
    return _headerAliases[h] ?? h;
  }

  static String detectDelimiter(String line) {
    final commas = ','.allMatches(line).length;
    final semis = ';'.allMatches(line).length;
    final tabs = '\t'.allMatches(line).length;
    if (tabs > 0 && tabs >= commas && tabs >= semis) return '\t';
    if (semis > commas) return ';';
    return ',';
  }

  static List<String> parseLine(String line, String delimiter) {
    if (delimiter == ',') return _parseQuotedCsvLine(line);
    return line
        .split(delimiter)
        .map((c) => _unquoteCell(c.trim()))
        .toList();
  }

  static String _unquoteCell(String cell) {
    if (cell.length >= 2 && cell.startsWith('"') && cell.endsWith('"')) {
      return cell.substring(1, cell.length - 1).replaceAll('""', '"');
    }
    return cell;
  }

  static List<String> _parseQuotedCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (ch == ',' && !inQuotes) {
        out.add(_unquoteCell(buf.toString().trim()));
        buf.clear();
        continue;
      }
      buf.write(ch);
    }
    out.add(_unquoteCell(buf.toString().trim()));
    return out;
  }

  static ({List<Map<String, dynamic>> rows, String? error}) parse(
    String csvText,
  ) {
    final text = stripBom(csvText);
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) {
      return (rows: <Map<String, dynamic>>[], error: 'CSV에 데이터 행이 없어요.');
    }

    final delimiter = detectDelimiter(lines.first);
    final header =
        parseLine(lines.first, delimiter).map(normalizeHeader).toList();

    int idx(String name) => header.indexOf(name);

    final brandIdx = idx('brand');
    final productIdx = idx('product_name');
    final imageIdx = idx('image_url');
    if (brandIdx < 0 || productIdx < 0 || imageIdx < 0) {
      return (
        rows: <Map<String, dynamic>>[],
        error:
            'CSV 헤더: brand, product_name, image_url 필수 (인식된 헤더: ${header.join(", ")})',
      );
    }
    final expiresIdx = idx('expires_at');
    final codeIdx = idx('coupon_code');

    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = parseLine(lines[i], delimiter);
      if (cols.isEmpty) continue;
      String cell(int index) =>
          index >= 0 && index < cols.length ? cols[index].trim() : '';

      final brand = cell(brandIdx);
      final product = cell(productIdx);
      final imageUrl = cell(imageIdx);
      if (brand.isEmpty || product.isEmpty || imageUrl.isEmpty) continue;

      rows.add({
        'brand': brand,
        'product_name': product,
        'image_url': imageUrl,
        if (expiresIdx >= 0 && cell(expiresIdx).isNotEmpty)
          'expires_at': cell(expiresIdx),
        if (codeIdx >= 0 && cell(codeIdx).isNotEmpty)
          'coupon_code': cell(codeIdx),
      });
    }

    if (rows.isEmpty) {
      return (rows: rows, error: '유효한 CSV 행이 없어요.');
    }
    return (rows: rows, error: null);
  }
}
