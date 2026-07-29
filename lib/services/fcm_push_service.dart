import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/push_token_repository.dart';
import '../firebase_options.dart';
import 'push_notification_service.dart';

/// FCM 원격 푸시 (앱 종료·백그라운드 포함)
class FcmPushService {
  FcmPushService._();
  static final FcmPushService instance = FcmPushService._();

  final _messaging = FirebaseMessaging.instance;
  final _tokenRepo = PushTokenRepository();
  final _local = FlutterLocalNotificationsPlugin();

  bool _firebaseReady = false;
  String? _currentToken;

  /// 탭 시 라우팅
  void Function(Map<String, dynamic> data)? onMessageOpened;

  /// data-only config_refresh → 로컬 스케줄 재동기화
  Future<void> Function()? onConfigRefresh;

  static const _channelId = 'fcm_remote';
  static const _channelName = '원격 푸시';

  Future<void> ensureFirebaseInitialized() async {
    if (kIsWeb) return;
    if (_firebaseReady) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    _firebaseReady = true;
  }

  Future<void> initialize({
    required void Function(Map<String, dynamic> data) onMessageOpened,
    Future<void> Function()? onConfigRefresh,
  }) async {
    if (kIsWeb) return;
    this.onMessageOpened = onMessageOpened;
    this.onConfigRefresh = onConfigRefresh;
    await ensureFirebaseInitialized();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _ensureLocalChannel();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleOpenedMessage(initial);
    }

    _messaging.onTokenRefresh.listen((token) async {
      _currentToken = token;
      try {
        await _tokenRepo.upsertToken(
          token: token,
          platform: PushTokenRepository.currentPlatformLabel(),
        );
      } catch (e, st) {
        debugPrint('[FCM] token refresh upsert failed: $e\n$st');
      }
    });
  }

  Future<void> _ensureLocalChannel() async {
    await PushNotificationService.instance.ensureReadyForPermissionRequest();
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: '서버(FCM)에서 보내는 알림',
            importance: Importance.high,
          ),
        );
  }

  Future<bool> requestPermissionAndRegister() async {
    if (kIsWeb) return false;
    await ensureFirebaseInitialized();
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return false;
    await registerToken();
    return true;
  }

  Future<void> registerToken() async {
    if (kIsWeb || !_firebaseReady) return;
    try {
      // iOS: APNs 기기 토큰이 오기 전에 getToken() 하면 apns-token-not-set
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apns;
        for (var i = 0; i < 10; i++) {
          apns = await _messaging.getAPNSToken();
          if (apns != null && apns.isNotEmpty) break;
          await Future<void>.delayed(Duration(milliseconds: 400 * (i + 1)));
        }
        if (apns == null || apns.isEmpty) {
          debugPrint(
            '[FCM] APNS token still missing after wait. '
            'Check: Push Notifications capability, aps-environment entitlement, '
            'Firebase APNs key, paid Apple Developer account.',
          );
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] getToken returned null');
        return;
      }
      _currentToken = token;
      await _tokenRepo.upsertToken(
        token: token,
        platform: PushTokenRepository.currentPlatformLabel(),
      );
      debugPrint('[FCM] token registered len=${token.length}');
    } catch (e, st) {
      debugPrint('[FCM] registerToken failed: $e\n$st');
    }
  }

  Future<void> unregisterToken() async {
    final token = _currentToken;
    if (token != null && token.isNotEmpty) {
      try {
        await _tokenRepo.deleteToken(token);
      } catch (e, st) {
        debugPrint('[FCM] deleteToken failed: $e\n$st');
      }
    }
    _currentToken = null;
    try {
      await _messaging.deleteToken();
    } catch (e, st) {
      debugPrint('[FCM] messaging.deleteToken failed: $e\n$st');
    }
  }

  Future<void> syncPrefs({
    required bool peakLunch,
    required bool peakDinner,
    required bool communityComments,
    required bool rewardGifticon,
    required bool news,
  }) async {
    try {
      await _tokenRepo.upsertPrefs(
        peakLunch: peakLunch,
        peakDinner: peakDinner,
        communityComments: communityComments,
        rewardGifticon: rewardGifticon,
        news: news,
      );
    } catch (e, st) {
      debugPrint('[FCM] syncPrefs failed: $e\n$st');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    debugPrint('[FCM] opened message data=$data');
    if (data['type'] == 'config_refresh') {
      onConfigRefresh?.call();
      return;
    }
    onMessageOpened?.call(data);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    if (data['type'] == 'config_refresh') {
      debugPrint('[FCM] config_refresh (foreground)');
      await onConfigRefresh?.call();
      return;
    }

    final n = message.notification;
    final title = n?.title ?? data['title'] as String? ?? '캠퍼스런치';
    final body = n?.body ?? data['body'] as String? ?? '';
    if (n == null && body.isEmpty) return;

    final payload = jsonEncode(data);
    await _local.show(
      message.hashCode & 0x7fffffff,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '서버(FCM)에서 보내는 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] background message id=${message.messageId}');
}
