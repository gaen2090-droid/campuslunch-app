/// 영업시간 파싱·영업 여부 판단 (Google Places / 앱 canonical 형식)
library;

class BusinessHoursData {
  /// 앱·DB 저장용: `11:00 - 21:00` 또는 `11:00 - 14:00, 17:00 - 22:00`
  final String hoursCanonical;

  /// 상세 화면용 요약 (요일별)
  final String hoursDisplay;

  /// Google `opening_hours.periods` 원본
  final List<Map<String, dynamic>> periods;

  const BusinessHoursData({
    required this.hoursCanonical,
    this.hoursDisplay = '',
    this.periods = const [],
  });

  static const defaultHours = '11:00 - 21:00';

  factory BusinessHoursData.fallback() => const BusinessHoursData(
        hoursCanonical: defaultHours,
        hoursDisplay: defaultHours,
      );

  factory BusinessHoursData.fromDescription(Map<String, dynamic>? extra) {
    if (extra == null) return BusinessHoursData.fallback();

    final periods = _readPeriods(extra['hours_periods']);
    final rawHours = (extra['hours'] as String?)?.trim() ?? '';
    final display =
        (extra['hours_display'] as String?)?.trim() ?? rawHours;

    if (periods.isNotEmpty) {
      final canonical = canonicalForDateTime(DateTime.now(), periods) ??
          _firstCanonicalFromPeriods(periods) ??
          defaultHours;
      return BusinessHoursData(
        hoursCanonical: canonical,
        hoursDisplay: display.isNotEmpty ? display : canonical,
        periods: periods,
      );
    }

    final ranges = parseCanonicalRanges(rawHours);
    if (ranges.isNotEmpty) {
      return BusinessHoursData(
        hoursCanonical: rawHours,
        hoursDisplay: display.isNotEmpty ? display : rawHours,
      );
    }

    final fromWeekday = parseTodayFromWeekdayBlob(rawHours, DateTime.now());
    if (fromWeekday != null) {
      return BusinessHoursData(
        hoursCanonical: fromWeekday,
        hoursDisplay: display.isNotEmpty ? display : rawHours,
      );
    }

    final fromDisplay = parseTodayFromWeekdayBlob(display, DateTime.now());
    if (fromDisplay != null) {
      return BusinessHoursData(
        hoursCanonical: fromDisplay,
        hoursDisplay: display,
      );
    }

    return BusinessHoursData.fallback();
  }

  factory BusinessHoursData.fromGoogleOpeningHours(
    Map<String, dynamic>? opening,
  ) {
    if (opening == null) return BusinessHoursData.fallback();

    final periods = <Map<String, dynamic>>[];
    final rawPeriods = opening['periods'] as List<dynamic>?;
    if (rawPeriods != null) {
      for (final p in rawPeriods) {
        if (p is Map) {
          periods.add(Map<String, dynamic>.from(p));
        }
      }
    }

    final weekday = opening['weekday_text'] as List<dynamic>?;
    final display = weekday == null
        ? ''
        : weekday.map((e) => e.toString()).join('\n');

    final now = DateTime.now();
    String canonical = defaultHours;
    if (periods.isNotEmpty) {
      canonical = canonicalForDateTime(now, periods) ??
          _firstCanonicalFromPeriods(periods) ??
          defaultHours;
    } else if (weekday != null) {
      canonical =
          parseTodayFromWeekdayBlob(weekday.join('\n'), now) ?? defaultHours;
    }

    return BusinessHoursData(
      hoursCanonical: canonical,
      hoursDisplay: compactWeekdayDisplay(weekday) ?? display,
      periods: periods,
    );
  }

  bool isOpenAt(DateTime now) {
    if (periods.isNotEmpty) {
      return _isOpenInGooglePeriods(now, periods);
    }
    final ranges = parseCanonicalRanges(hoursCanonical);
    if (ranges.isNotEmpty) {
      return _isNowWithinRanges(now, ranges);
    }
    final today = parseTodayFromWeekdayBlob(hoursDisplay, now);
    if (today != null) {
      final tr = parseCanonicalRanges(today);
      return tr.isNotEmpty && _isNowWithinRanges(now, tr);
    }
    return false;
  }

  Map<String, dynamic> toDescriptionFields() => {
        'hours': hoursCanonical,
        if (hoursDisplay.isNotEmpty) 'hours_display': hoursDisplay,
        if (periods.isNotEmpty) 'hours_periods': periods,
      };

  // ── Google periods ──

  static bool _isOpenInGooglePeriods(
    DateTime now,
    List<Map<String, dynamic>> periods,
  ) {
    final nowMin = _weekMinute(_googleDay(now), now.hour * 60 + now.minute);
    for (final p in periods) {
      final open = p['open'] as Map<String, dynamic>?;
      final close = p['close'] as Map<String, dynamic>?;
      if (open == null || close == null) continue;
      var start = _weekMinute(
        (open['day'] as num).toInt(),
        _parseGoogleTime(open['time'] as String?),
      );
      var end = _weekMinute(
        (close['day'] as num).toInt(),
        _parseGoogleTime(close['time'] as String?),
      );
      if (end <= start) end += 7 * 1440;
      var cmp = nowMin;
      if (cmp < start) cmp += 7 * 1440;
      if (cmp >= start && cmp < end) return true;
    }
    return false;
  }

  static int _googleDay(DateTime d) => d.weekday == DateTime.sunday ? 0 : d.weekday;

  static int _weekMinute(int day, int minuteOfDay) => day * 1440 + minuteOfDay;

  static int _parseGoogleTime(String? t) {
    if (t == null || t.length < 3) return 0;
    final h = int.tryParse(t.substring(0, t.length - 2)) ?? 0;
    final m = int.tryParse(t.substring(t.length - 2)) ?? 0;
    return h * 60 + m;
  }

  static String? canonicalForDateTime(
    DateTime now,
    List<Map<String, dynamic>> periods,
  ) {
    final day = _googleDay(now);
    final ranges = <(int, int)>[];
    for (final p in periods) {
      final open = p['open'] as Map<String, dynamic>?;
      final close = p['close'] as Map<String, dynamic>?;
      if (open == null || close == null) continue;
      if ((open['day'] as num).toInt() != day) continue;
      final s = _parseGoogleTime(open['time'] as String?);
      var e = _parseGoogleTime(close['time'] as String?);
      final closeDay = (close['day'] as num).toInt();
      if (closeDay != day && e <= s) e += 24 * 60;
      if (e > s) ranges.add((s, e));
    }
    if (ranges.isEmpty) return null;
    return _formatRanges(ranges);
  }

  static String? _firstCanonicalFromPeriods(
    List<Map<String, dynamic>> periods,
  ) {
    final byDay = <int, List<(int, int)>>{};
    for (final p in periods) {
      final open = p['open'] as Map<String, dynamic>?;
      final close = p['close'] as Map<String, dynamic>?;
      if (open == null || close == null) continue;
      final day = (open['day'] as num).toInt();
      final s = _parseGoogleTime(open['time'] as String?);
      var e = _parseGoogleTime(close['time'] as String?);
      if (e <= s) e += 24 * 60;
      byDay.putIfAbsent(day, () => []).add((s, e));
    }
    if (byDay.isEmpty) return null;
    final first = byDay.values.first;
    return _formatRanges(first);
  }

  // ── Canonical `HH:mm - HH:mm` ──

  static List<(int startMin, int endMin)> parseCanonicalRanges(String hours) {
    final ranges = <(int, int)>[];
    for (final part in hours.split(',')) {
      final m = RegExp(r'(\d{1,2}):(\d{2})\s*[-~–—]\s*(\d{1,2}):(\d{2})')
          .firstMatch(part.trim());
      if (m != null) {
        final s = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
        var e = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
        if (e <= s) e += 24 * 60;
        ranges.add((s, e));
      }
    }
    return ranges;
  }

  static bool _isNowWithinRanges(
    DateTime now,
    List<(int startMin, int endMin)> ranges,
  ) {
    final nowMins = now.hour * 60 + now.minute;
    for (final r in ranges) {
      if (r.$2 <= 24 * 60) {
        if (nowMins >= r.$1 && nowMins < r.$2) return true;
      } else {
        final end = r.$2 % (24 * 60);
        if (nowMins >= r.$1 || nowMins < end) return true;
      }
    }
    return false;
  }

  static String _formatRanges(List<(int, int)> ranges) {
    String fmt(int m) {
      final h = (m ~/ 60) % 24;
      final min = m % 60;
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }

    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    return ranges.map((r) => '${fmt(r.$1)} - ${fmt(r.$2)}').join(', ');
  }

  /// 관리자 편집 화면용 시간 구간
  static List<({String from, String to})> rangesForEdit(String hours) {
    final data = BusinessHoursData.fromDescription({'hours': hours});
    final parsed = parseCanonicalRanges(data.hoursCanonical);
    if (parsed.isEmpty) {
      return [(from: '11:00', to: '21:00')];
    }
    String fmt(int m) {
      final h = m ~/ 60;
      final min = m % 60;
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }

    return parsed
        .map((r) => (from: fmt(r.$1), to: fmt(r.$2 > 24 * 60 ? r.$2 % (24 * 60) : r.$2)))
        .toList();
  }

  // ── weekday_text (한/영) ──

  static const _dayPrefixes = [
    ('월', 1),
    ('화', 2),
    ('수', 3),
    ('목', 4),
    ('금', 5),
    ('토', 6),
    ('일', 7),
  ];

  static String? parseTodayFromWeekdayBlob(String blob, DateTime now) {
    if (blob.isEmpty) return null;
    final targetDay = now.weekday;
    for (final line in blob.split(RegExp(r'[\n,]'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!_lineMatchesDay(trimmed, targetDay)) continue;
      if (RegExp(r'휴무|closed|Closed|정기\s*휴무', caseSensitive: false)
          .hasMatch(trimmed)) {
        return null;
      }
      final ranges = _extractTimeRangesFromLine(trimmed);
      if (ranges.isNotEmpty) return _formatRanges(ranges);
    }
    return null;
  }

  static bool _lineMatchesDay(String line, int dartWeekday) {
    final lower = line.toLowerCase();
    const en = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    if (dartWeekday >= 1 && dartWeekday <= 7) {
      if (lower.contains(en[dartWeekday - 1])) return true;
    }
    for (final (prefix, day) in _dayPrefixes) {
      if (day == dartWeekday &&
          (line.startsWith(prefix) ||
              line.contains('$prefix요일') ||
              line.contains('$prefix:'))) {
        return true;
      }
    }
    return false;
  }

  static List<(int, int)> _extractTimeRangesFromLine(String line) {
    final ranges = <(int, int)>[];
    final pattern = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM|오전|오후)?',
      caseSensitive: false,
    );
    final matches = pattern.allMatches(line).toList();
    for (var i = 0; i + 1 < matches.length; i += 2) {
      final s = _matchToMinutes(matches[i]);
      final e = _matchToMinutes(matches[i + 1]);
      if (s != null && e != null && e > s) ranges.add((s, e));
    }
    return ranges;
  }

  static int? _matchToMinutes(RegExpMatch m) {
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ampm = m.group(3)?.toUpperCase();
    if (ampm == 'PM' || ampm == '오후') {
      if (h < 12) h += 12;
    } else if (ampm == 'AM' || ampm == '오전') {
      if (h == 12) h = 0;
    }
    return h * 60 + min;
  }

  static String? compactWeekdayDisplay(List<dynamic>? weekday) {
    if (weekday == null || weekday.isEmpty) return null;
    final parts = <String>[];
    for (final raw in weekday) {
      final line = raw.toString();
      final dayMatch = RegExp(r'^([월화수목금토일])').firstMatch(line);
      final day = dayMatch?.group(1) ?? '';
      if (RegExp(r'휴무|closed', caseSensitive: false).hasMatch(line)) {
        parts.add('$day 휴무');
        continue;
      }
      final times = RegExp(r'(\d{1,2}:\d{2}).*?(\d{1,2}:\d{2})').firstMatch(line);
      if (day.isNotEmpty && times != null) {
        parts.add('$day ${times.group(1)}-${times.group(2)}');
      }
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// UI용 요일별 줄 목록 (`월 11:00-21:00` 형태)
  static List<String> displayLines(String hours) {
    final t = hours.trim();
    if (t.isEmpty) return [];
    if (t.contains('·')) {
      return t
          .split('·')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (t.contains('\n')) {
      return t
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [t];
  }

  /// 접힌 상태: 오늘 요일 1줄 (없으면 첫 줄)
  static String collapsedDisplayLine(String hours, DateTime now) {
    final lines = displayLines(hours);
    if (lines.isEmpty) return hours;

    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final today = dayNames[now.weekday - 1];

    for (final line in lines) {
      if (line.startsWith(today) ||
          line.startsWith('$today요일') ||
          line.contains(' $today ')) {
        return line;
      }
    }

    final todayHours = parseTodayFromWeekdayBlob(hours, now);
    if (todayHours != null) {
      if (RegExp(r'휴무|closed', caseSensitive: false).hasMatch(hours)) {
        for (final line in lines) {
          if (line.startsWith(today)) return line;
        }
      }
      return '$today $todayHours';
    }

    return lines.first;
  }

  static List<Map<String, dynamic>> _readPeriods(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
}
