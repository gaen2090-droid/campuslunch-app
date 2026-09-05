/// 스탬프·리워드 UI 상수 (서버 grant_stamp 일일 한도와 맞출 것)
abstract final class RewardLimits {
  /// KST 기준 하루 최대 스탬프 (출시값). 서버 SQL도 동일해야 함.
  static const int dailyStampCap = 3;

  /// 기프티콘 교환에 필요한 누적 스탬프
  static const int stampsPerGifticon = 20;

  /// 스탬프 지급 시간대(KST). 서버 grant_stamp(stamp_hours_11_to_19.sql)와 동일해야 함.
  /// 이 시간 밖에서도 제보는 가능하지만 스탬프는 지급되지 않음.
  static const int stampHourStart = 11;
  static const int stampHourEnd = 19;

  /// 주말(토·일)에는 시간대와 무관하게 스탬프 미지급. 서버 grant_stamp와 동일해야 함.
  static bool isWeekend(DateTime now) =>
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

  static bool isWithinStampHours(DateTime now) =>
      !isWeekend(now) && now.hour >= stampHourStart && now.hour < stampHourEnd;
}
