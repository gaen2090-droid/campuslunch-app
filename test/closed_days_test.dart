import 'package:campus_lunch/utils/business_hours.dart';
import 'package:campus_lunch/utils/korean_holidays.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _desc({
  List<int>? closedDays,
  bool onHolidays = false,
  String hours = '11:00 - 21:00',
}) =>
    {
      'hours': hours,
      'hours_display': hours,
      if (closedDays != null) 'closed_days': closedDays,
      if (onHolidays) 'closed_on_holidays': true,
    };

void main() {
  // 2026-10-11 일, 10-12 월, 10-14 수
  final sunNoon = DateTime(2026, 10, 11, 12);
  final monNoon = DateTime(2026, 10, 12, 12);
  final wedNoon = DateTime(2026, 10, 14, 12);

  group('정기 휴무 요일', () {
    test('휴무 설정이 없으면 매일 영업', () {
      final bh = BusinessHoursData.fromDescription(_desc());
      expect(bh.isOpenAt(sunNoon), isTrue);
      expect(bh.isOpenAt(monNoon), isTrue);
    });

    test('일요일 휴무면 일요일에만 닫는다', () {
      final bh = BusinessHoursData.fromDescription(_desc(closedDays: [7]));
      expect(bh.isOpenAt(sunNoon), isFalse);
      expect(bh.isOpenAt(monNoon), isTrue);
    });

    test('월요일 휴무', () {
      final bh = BusinessHoursData.fromDescription(_desc(closedDays: [1]));
      expect(bh.isOpenAt(monNoon), isFalse);
      expect(bh.isOpenAt(wedNoon), isTrue);
    });

    test('범위를 벗어난 값은 무시한다', () {
      final bh = BusinessHoursData.fromDescription(_desc(closedDays: [0, 8, 9]));
      expect(bh.isOpenAt(wedNoon), isTrue);
      expect(bh.closedWeekdays, isEmpty);
    });

    test('자정을 넘기는 영업은 전날 휴무를 따른다 (새벽 5시 전)', () {
      // 월요일 휴무, 14:00 - 03:00 영업: 화요일 새벽 1시는 월요일 영업의 연장이라 휴무
      final bh = BusinessHoursData.fromDescription(
        _desc(closedDays: [1], hours: '14:00 - 03:00'),
      );
      expect(bh.isOpenAt(DateTime(2026, 10, 13, 1)), isFalse);
      // 일요일 영업의 연장인 월요일 새벽 1시는 영업 중
      expect(bh.isOpenAt(DateTime(2026, 10, 12, 1)), isTrue);
    });
  });

  group('공휴일 휴무', () {
    test('공휴일 목록', () {
      expect(isKoreanPublicHoliday(DateTime(2026, 10, 9)), isTrue); // 한글날
      expect(isKoreanPublicHoliday(DateTime(2026, 12, 25)), isTrue); // 성탄절
      expect(isKoreanPublicHoliday(DateTime(2027, 2, 9)), isTrue); // 설 대체공휴일
      expect(isKoreanPublicHoliday(DateTime(2026, 10, 14)), isFalse);
      expect(isKoreanPublicHoliday(DateTime(2026, 5, 1)), isFalse); // 근로자의 날 제외
    });

    test('공휴일 휴무 매장은 공휴일에만 닫는다', () {
      final bh = BusinessHoursData.fromDescription(_desc(onHolidays: true));
      expect(bh.isOpenAt(DateTime(2026, 10, 9, 12)), isFalse); // 한글날(금)
      expect(bh.isOpenAt(DateTime(2026, 10, 8, 12)), isTrue);
    });

    test('공휴일 휴무가 아닌 매장은 공휴일에도 영업', () {
      final bh = BusinessHoursData.fromDescription(_desc());
      expect(bh.isOpenAt(DateTime(2026, 10, 9, 12)), isTrue);
    });

    test('요일 휴무와 공휴일 휴무를 함께 쓸 수 있다', () {
      final bh = BusinessHoursData.fromDescription(
        _desc(closedDays: [7], onHolidays: true),
      );
      expect(bh.isOpenAt(sunNoon), isFalse);
      expect(bh.isOpenAt(DateTime(2026, 10, 9, 12)), isFalse);
      expect(bh.isOpenAt(wedNoon), isTrue);
    });
  });
}
