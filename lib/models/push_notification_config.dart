/// Supabase `push_notification_config` (피크 로컬 기본 + 커뮤니티 FCM 문구)
class PushNotificationConfig {
  const PushNotificationConfig({
    this.lunchHour = 12,
    this.lunchMinute = 0,
    this.dinnerHour = 18,
    this.dinnerMinute = 0,
    this.titleTemplate = '{gate}에서 대기 없이 식사할 수 있어요',
    this.bodyTemplate =
        '지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >',
    this.weekdaysOnly = true,
    this.scheduleDaysAhead = 14,
    this.peakFcmEnabled = false,
    this.communityFcmEnabled = true,
    this.peakLocalScheduleEnabled = true,
  });

  final int lunchHour;
  final int lunchMinute;
  final int dinnerHour;
  final int dinnerMinute;
  final String titleTemplate;
  final String bodyTemplate;
  final bool weekdaysOnly;
  final int scheduleDaysAhead;
  final bool peakFcmEnabled;
  final bool communityFcmEnabled;

  /// 로컬 zonedSchedule (기본 ON). 서버 문구·시각 사용.
  final bool peakLocalScheduleEnabled;

  static const defaults = PushNotificationConfig();

  factory PushNotificationConfig.fromJson(Map<String, dynamic> json) {
    int readInt(Object? v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    bool readBool(Object? v, bool fallback) {
      if (v is bool) return v;
      if (v == 'true') return true;
      if (v == 'false') return false;
      return fallback;
    }

    return PushNotificationConfig(
      lunchHour: readInt(json['lunch_hour'], defaults.lunchHour),
      lunchMinute: readInt(json['lunch_minute'], defaults.lunchMinute),
      dinnerHour: readInt(json['dinner_hour'], defaults.dinnerHour),
      dinnerMinute: readInt(json['dinner_minute'], defaults.dinnerMinute),
      titleTemplate: (json['title_template'] as String?)?.trim().isNotEmpty == true
          ? (json['title_template'] as String).trim()
          : defaults.titleTemplate,
      bodyTemplate: (json['body_template'] as String?)?.trim().isNotEmpty == true
          ? (json['body_template'] as String).trim()
          : defaults.bodyTemplate,
      weekdaysOnly: readBool(json['weekdays_only'], defaults.weekdaysOnly),
      scheduleDaysAhead: readInt(
        json['schedule_days_ahead'],
        defaults.scheduleDaysAhead,
      ),
      peakFcmEnabled: readBool(json['peak_fcm_enabled'], defaults.peakFcmEnabled),
      communityFcmEnabled:
          readBool(json['community_fcm_enabled'], defaults.communityFcmEnabled),
      peakLocalScheduleEnabled: readBool(
        json['peak_local_schedule_enabled'],
        defaults.peakLocalScheduleEnabled,
      ),
    );
  }

  String formatTitle(String gate) =>
      titleTemplate.replaceAll('{gate}', gate);

  String get lunchTimeLabel =>
      '${lunchHour.toString().padLeft(2, '0')}:'
      '${lunchMinute.toString().padLeft(2, '0')}';

  String get dinnerTimeLabel =>
      '${dinnerHour.toString().padLeft(2, '0')}:'
      '${dinnerMinute.toString().padLeft(2, '0')}';
}
