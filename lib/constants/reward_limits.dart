/// 스탬프·리워드 UI 상수 (서버 grant_stamp 일일 한도와 맞출 것)
abstract final class RewardLimits {
  /// KST 기준 하루 최대 스탬프 (출시값). 서버 SQL도 동일해야 함.
  static const int dailyStampCap = 3;

  /// 기프티콘 교환에 필요한 누적 스탬프
  static const int stampsPerGifticon = 20;
}
