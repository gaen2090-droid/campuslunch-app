/// Supabase `push_notification_config` (피크 로컬 기본 + 커뮤니티 FCM 문구)
class PeakPushSchedule {
  const PeakPushSchedule({
    required this.id,
    required this.label,
    this.enabled = true,
    required this.hour,
    required this.minute,
    required this.titleTemplate,
    required this.bodyTemplate,
  });

  final String id;
  final String label;
  final bool enabled;
  final int hour;
  final int minute;
  final String titleTemplate;
  final String bodyTemplate;

  String formatTitle([String? gate]) {
    var t = titleTemplate;
    if (gate != null && gate.isNotEmpty) {
      t = t.replaceAll('{gate}', gate);
    }
    return t.replaceAll('{gate}', '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String formatBody([String? gate]) {
    var t = bodyTemplate;
    if (gate != null && gate.isNotEmpty) {
      t = t.replaceAll('{gate}', gate);
    }
    return t.replaceAll('{gate}', '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  factory PeakPushSchedule.fromJson(
    Map<String, dynamic> json, {
    required PeakPushSchedule fallback,
  }) {
    int readInt(Object? v, int fb) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fb;
    }

    String clean(String? raw, String fb) {
      final s = (raw ?? '').trim();
      if (s.isEmpty) return fb;
      return s
          .replaceAll('{gate}', '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    return PeakPushSchedule(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : fallback.id,
      label: (json['label'] as String?)?.trim().isNotEmpty == true
          ? (json['label'] as String).trim()
          : fallback.label,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : fallback.enabled,
      hour: readInt(json['hour'], fallback.hour).clamp(0, 23),
      minute: readInt(json['minute'], fallback.minute).clamp(0, 59),
      titleTemplate: clean(
        json['title_template'] as String? ?? json['titleTemplate'] as String?,
        fallback.titleTemplate,
      ),
      bodyTemplate: clean(
        json['body_template'] as String? ?? json['bodyTemplate'] as String?,
        fallback.bodyTemplate,
      ),
    );
  }
}

class PushNotificationConfig {
  const PushNotificationConfig({
    this.schedules = const [],
    this.lunchHour = 12,
    this.lunchMinute = 0,
    this.dinnerHour = 18,
    this.dinnerMinute = 0,
    this.titleTemplate = '대기 없이 식사할 수 있어요',
    this.bodyTemplate =
        '지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >',
    this.weekdaysOnly = true,
    this.scheduleDaysAhead = 14,
    this.peakFcmEnabled = false,
    this.communityFcmEnabled = true,
    this.peakLocalScheduleEnabled = true,
  });

  final List<PeakPushSchedule> schedules;
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

  static const _defaultLunch = PeakPushSchedule(
    id: 'lunch',
    label: '점심',
    hour: 12,
    minute: 0,
    titleTemplate: '대기 없이 식사할 수 있어요',
    bodyTemplate: '지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >',
  );

  static const _defaultDinner = PeakPushSchedule(
    id: 'dinner',
    label: '저녁',
    hour: 18,
    minute: 0,
    titleTemplate: '대기 없이 식사할 수 있어요',
    bodyTemplate: '지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >',
  );

  static const defaults = PushNotificationConfig(
    schedules: [_defaultLunch, _defaultDinner],
  );

  List<PeakPushSchedule> get effectiveSchedules {
    if (schedules.isNotEmpty) return schedules;
    return [
      PeakPushSchedule(
        id: 'lunch',
        label: '점심',
        hour: lunchHour,
        minute: lunchMinute,
        titleTemplate: titleTemplate,
        bodyTemplate: bodyTemplate,
      ),
      PeakPushSchedule(
        id: 'dinner',
        label: '저녁',
        hour: dinnerHour,
        minute: dinnerMinute,
        titleTemplate: titleTemplate,
        bodyTemplate: bodyTemplate,
      ),
    ];
  }

  List<PeakPushSchedule> get enabledSchedules =>
      effectiveSchedules.where((s) => s.enabled).toList();

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

    String cleanTemplate(String? raw, String fallback) {
      final s = (raw ?? '').trim();
      if (s.isEmpty) return fallback;
      return s
          .replaceAll('{gate}', '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    final rawSchedules = json['peak_schedules'];
    List<PeakPushSchedule> parsed = const [];
    if (rawSchedules is List && rawSchedules.isNotEmpty) {
      parsed = [
        for (var i = 0; i < rawSchedules.length; i++)
          PeakPushSchedule.fromJson(
            Map<String, dynamic>.from(rawSchedules[i] as Map),
            fallback: i == 0 ? _defaultLunch : _defaultDinner,
          ),
      ];
    }

    final title = cleanTemplate(
      json['title_template'] as String?,
      defaults.titleTemplate,
    );
    final body = cleanTemplate(
      json['body_template'] as String?,
      defaults.bodyTemplate,
    );

    return PushNotificationConfig(
      schedules: parsed,
      lunchHour: readInt(json['lunch_hour'], defaults.lunchHour),
      lunchMinute: readInt(json['lunch_minute'], defaults.lunchMinute),
      dinnerHour: readInt(json['dinner_hour'], defaults.dinnerHour),
      dinnerMinute: readInt(json['dinner_minute'], defaults.dinnerMinute),
      titleTemplate: title,
      bodyTemplate: body,
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
      titleTemplate.replaceAll('{gate}', gate).replaceAll('{gate}', '');

  String get lunchTimeLabel =>
      '${lunchHour.toString().padLeft(2, '0')}:'
      '${lunchMinute.toString().padLeft(2, '0')}';

  String get dinnerTimeLabel =>
      '${dinnerHour.toString().padLeft(2, '0')}:'
      '${dinnerMinute.toString().padLeft(2, '0')}';
}
