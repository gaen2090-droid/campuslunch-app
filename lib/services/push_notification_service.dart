import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/analytics_repository.dart';
import '../models/push_notification_config.dart';
import '../models/restaurant.dart';
import '../utils/available_restaurant_ranking.dart';
import '../utils/gate_label.dart';

/// 피크 추천 로컬 푸시 (admin peak_schedules 기준)
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AnalyticsRepository _analytics = AnalyticsRepository();

  bool _initialized = false;
  void Function(String? restaurantId)? onOpenHome;

  static const _channelId = 'peak_recommendation';
  static const _channelName = '피크 추천 알림';

  Future<void> initialize({
    required void Function(String? restaurantId) onOpenHome,
  }) async {
    this.onOpenHome = onOpenHome;
    await _ensurePluginReady(registerTapHandlers: true);
  }

  /// 권한 요청 전 플러그인 초기화 (deferred startup 이전에도 동작)
  Future<void> ensureReadyForPermissionRequest() async {
    await _ensurePluginReady(registerTapHandlers: true);
  }

  Future<void> _ensurePluginReady({required bool registerTapHandlers}) async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse:
          registerTapHandlers ? _onForegroundResponse : null,
      onDidReceiveBackgroundNotificationResponse:
          registerTapHandlers ? _onBackgroundResponse : null,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: '평일 점심·저녁 피크 시간대 추천 매장 알림',
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await ensureReadyForPermissionRequest();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> refreshSchedules({
    required bool lunchEnabled,
    required bool dinnerEnabled,
    required List<Restaurant> restaurants,
    required bool useAlgorithmRanking,
    PushNotificationConfig config = PushNotificationConfig.defaults,
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();

    // 어드민 peak_local_schedule_enabled=false 이면 로컬 예약 안 함 (서버 FCM만)
    if (!config.peakLocalScheduleEnabled) return;
    if (!lunchEnabled && !dinnerEnabled) return;

    final recommended = pickRecommendedRestaurant(
      restaurants,
      useAlgorithmRanking,
    );
    if (recommended == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;
    final maxDays = config.scheduleDaysAhead.clamp(1, 30);
    const maxNotifications = 20;
    final slots = config.enabledSchedules;

    for (var dayOffset = 0;
        dayOffset < maxDays && scheduled < maxNotifications;
        dayOffset++) {
      final day = now.add(Duration(days: dayOffset));
      if (config.weekdaysOnly && !_isWeekday(day)) continue;

      for (var i = 0; i < slots.length && scheduled < maxNotifications; i++) {
        final slot = slots[i];
        if (!_userWantsSlot(slot.id, lunchEnabled, dinnerEnabled)) continue;

        final at = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          slot.hour,
          slot.minute,
        );
        if (!at.isAfter(now)) continue;

        await _scheduleSlot(
          schedule: slot,
          scheduleIndex: i,
          at: at,
          restaurant: recommended,
        );
        scheduled++;
      }
    }
  }

  bool _userWantsSlot(String id, bool lunchEnabled, bool dinnerEnabled) {
    if (id == 'lunch') return lunchEnabled;
    if (id == 'dinner') return dinnerEnabled;
    return lunchEnabled || dinnerEnabled;
  }

  Future<void> cancelAllSchedules() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> _scheduleSlot({
    required PeakPushSchedule schedule,
    required int scheduleIndex,
    required tz.TZDateTime at,
    required Restaurant restaurant,
  }) async {
    final gate = gateLabelFromRestaurant(restaurant);
    final id = _notificationId(scheduleIndex, at);
    final payload = jsonEncode({
      'type': 'peak',
      'slot': schedule.id,
      'restaurant_id': restaurant.id,
      'gate': gate,
    });

    await _plugin.zonedSchedule(
      id,
      schedule.formatTitle(),
      schedule.formatBody(),
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '피크 시간대 추천 매장 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  int _notificationId(int scheduleIndex, tz.TZDateTime at) =>
      (scheduleIndex + 1) * 100000 +
      (at.year % 100) * 10000 +
      at.month * 100 +
      at.day;

  Future<void> syncDeliveredAnalytics({
    required bool lunchEnabled,
    required bool dinnerEnabled,
    String? restaurantId,
    PushNotificationConfig config = PushNotificationConfig.defaults,
  }) async {
    if (!lunchEnabled && !dinnerEnabled) return;
    final now = tz.TZDateTime.now(tz.local);
    if (config.weekdaysOnly && !_isWeekday(now)) return;

    final prefs = await SharedPreferences.getInstance();
    for (final slot in config.enabledSchedules) {
      if (!_userWantsSlot(slot.id, lunchEnabled, dinnerEnabled)) continue;
      await _maybeRecordDelivered(
        prefs: prefs,
        slotId: slot.id,
        hour: slot.hour,
        minute: slot.minute,
        now: now,
        restaurantId: restaurantId,
      );
    }
  }

  Future<void> _maybeRecordDelivered({
    required SharedPreferences prefs,
    required String slotId,
    required int hour,
    int minute = 0,
    required tz.TZDateTime now,
    String? restaurantId,
  }) async {
    final fireAt = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (now.isBefore(fireAt)) return;
    if (now.difference(fireAt) > const Duration(hours: 3)) return;

    final dayKey = '${slotId}_${now.year}${now.month}${now.day}';
    final prefKey = 'cl_push_delivered_$dayKey';
    if (prefs.getBool(prefKey) == true) return;

    await _analytics.recordPushDelivered(
      slot: slotId,
      restaurantId: restaurantId,
      dayKey: dayKey,
    );
    await prefs.setBool(prefKey, true);
  }

  bool _isWeekday(tz.TZDateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  /// 디버그: [delay] 후 알림 1건 예약. 앱을 완전히 종료한 뒤 수신 확인용.
  Future<String> scheduleDebugNotification({
    required List<Restaurant> restaurants,
    required bool useAlgorithmRanking,
    Duration delay = const Duration(seconds: 30),
  }) async {
    if (!_initialized) return '푸시 서비스가 초기화되지 않았어요.';

    final recommended = pickRecommendedRestaurant(
      restaurants,
      useAlgorithmRanking,
    );
    if (recommended == null) {
      return '바로 입장 가능 매장(여유로움/약간혼잡)이 없어서 예약할 수 없어요.';
    }

    final at = tz.TZDateTime.now(tz.local).add(delay);
    final gate = gateLabelFromRestaurant(recommended);
    const debugId = 999999;
    final payload = jsonEncode({
      'slot': 'debug',
      'restaurant_id': recommended.id,
      'gate': gate,
    });

    await _plugin.zonedSchedule(
      debugId,
      '[테스트] 대기 없이 식사할 수 있어요',
      '지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >',
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '평일 점심·저녁 피크 시간대 추천 매장 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    final secs = delay.inSeconds;
    return '${secs}초 후(${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}) '
        '알림 예약됨 · 매장: ${recommended.name}($gate)\n'
        '앱을 스와이프로 완전히 종료한 뒤 기다려보세요.';
  }

  /// 예약된 알림 목록 (디버그 로그용)
  Future<List<String>> pendingNotificationSummaries() async {
    if (!_initialized) return [];
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .map((n) => 'id=${n.id} title=${n.title ?? '-'} body=${n.body ?? '-'}')
        .toList();
  }

  Future<void> logPendingNotifications() async {
    final lines = await pendingNotificationSummaries();
    debugPrint('[Push] pending count=${lines.length}');
    for (final line in lines) {
      debugPrint('[Push]  $line');
    }
  }
}

void _onForegroundResponse(NotificationResponse response) {
  _handlePushResponse(response, navigate: true);
}

@pragma('vm:entry-point')
void _onBackgroundResponse(NotificationResponse response) {
  _handlePushResponse(response, navigate: false);
}

void _handlePushResponse(NotificationResponse response, {required bool navigate}) {
  debugPrint(
    '[Push] _handlePushResponse navigate=$navigate id=${response.id} '
    'actionId=${response.actionId} payload=${response.payload}',
  );
  final payload = response.payload;
  String? restaurantId;
  Map<String, dynamic>? map;
  if (payload != null && payload.isNotEmpty) {
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
      restaurantId = map['restaurant_id'] as String?;
      final slot = map['slot'] as String? ?? 'lunch';
      AnalyticsRepository().recordPushClick(
        slot: slot,
        restaurantId: restaurantId,
      );
    } catch (e) {
      debugPrint('[Push] payload parse failed: $e');
    }
  }
  if (!navigate) return;
  if (map != null && map['type'] != null) {
    onLocalNotificationPayload?.call(map);
    return;
  }
  PushNotificationService.instance.onOpenHome?.call(restaurantId);
}

bool isWeekdayKst(DateTime date) {
  final local = date.toLocal();
  return local.weekday >= DateTime.monday && local.weekday <= DateTime.friday;
}

/// 포그라운드 FCM → 로컬 표시 후 탭 시 데이터 페이로드 전달
void Function(Map<String, dynamic> data)? onLocalNotificationPayload;
