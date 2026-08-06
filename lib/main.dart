import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/env.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'services/app_link_service.dart';
import 'services/fcm_push_service.dart';
import 'services/google_auth_service.dart';
import 'services/kakao_auth_service.dart';
import 'services/kakao_map_bootstrap.dart';
import 'services/push_notification_service.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/legal_terms_consent_screen.dart';
import 'screens/permissions_consent_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/notification_permission_screen.dart';
import 'screens/usage_guide_screen.dart';
import 'screens/referral_code_screen.dart';
import 'navigation/app_route_observer.dart';
import 'utils/app_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[Env] .env load failed, using native_keys.json fallback: $e');
  }
  await Env.loadReleaseConfig();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      debugPrint('[Firebase] initialize failed: $e\n$st');
    }
  }

  if (Env.isSupabaseConfigured) {
    try {
      await SupabaseService.initialize();
    } catch (e, st) {
      debugPrint('[Supabase] initialize failed: $e\n$st');
    }
  } else if (kDebugMode) {
    debugPrint(
      '[Supabase] SUPABASE_URL/ANON_KEY가 비어 있어 로컬 데이터만 사용합니다.',
    );
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await preloadSplashResources();

  // ChangeNotifierProvider의 create는 위젯 빌드 시점까지 지연 실행되므로,
  // runApp 직후 곧바로 appProvider를 참조하려면 runApp 이전에 만들어둬야 한다.
  final appProvider = AppProvider()..init();
  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const CampusLunchApp(),
    ),
  );

  // 카카오·지도·푸시·Google — 권한 안내 확인 이후에만 (OS 권한 팝업 선행 방지)
  runDeferredStartupOnce = () => _deferredStartup(appProvider);

  unawaited(AppLinkService.instance.initialize(appProvider));
}

Future<void> _deferredStartup(AppProvider provider) async {
  await KakaoAuthService.initialize();
  unawaited(GoogleAuthService.initialize());
  unawaited(KakaoMapBootstrap.ensureInitialized());
  try {
    onLocalNotificationPayload = provider.handleRemotePushData;
    await PushNotificationService.instance.initialize(
      onOpenHome: (id) => provider.openHomeFromPush(id),
    );
    await FcmPushService.instance.initialize(
      onMessageOpened: provider.handleRemotePushData,
      onConfigRefresh: () => provider.refreshPushSchedulesFromRemote(),
    );
    if (provider.notificationEnabled && provider.hasSupabaseSession) {
      unawaited(FcmPushService.instance.registerToken());
    }
  } catch (e, st) {
    debugPrint('[Push] deferred init failed: $e\n$st');
  }
}

class CampusLunchApp extends StatelessWidget {
  const CampusLunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '캠퍼스런치',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey.shade900,
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF000000),
          onPrimary: Colors.white,
        ),
        fontFamily: 'Pretendard',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F8F0),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: const TextTheme(
          displayLarge:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          displayMedium: TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          displaySmall:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          headlineLarge:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          headlineMedium: TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          headlineSmall:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          titleLarge:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          titleMedium: TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          titleSmall:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          bodyLarge:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          bodyMedium: TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          bodySmall:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          labelLarge:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          labelMedium: TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
          labelSmall:  TextStyle(fontFamily: 'Pretendard', letterSpacing: -0.5),
        ),
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // 아이폰 15(393pt)를 디자인 기준 화면으로 삼는다. 그보다 좁은 화면은
        // 확대하지 않고, 넓은 화면(17 Pro 등 대형 기기)만 393pt 대비 커진
        // 비율만큼 텍스트를 확대해 15에서 보던 밀도에 맞춘다.
        const baseWidth = 393.0;
        final factor = (mq.size.width / baseWidth).clamp(1.0, double.infinity);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1.0) * factor),
          ),
          child: child!,
        );
      },
      home: const _Root(),
      navigatorObservers: [appRouteObserver],
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String? _previousStage;

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AppProvider>().stage;
    _clearStaleRoutesIfNeeded(stage);

    return switch (stage) {
      'splash' => const SplashScreen(key: ValueKey('splash')),
      'permissions_consent' =>
        const PermissionsConsentScreen(key: ValueKey('permissions_consent')),
      'legal_terms_consent' =>
        const LegalTermsConsentScreen(key: ValueKey('legal_terms_consent')),
      'login' => const LoginScreen(key: ValueKey('login')),
      'location_permission' =>
        const LocationPermissionScreen(key: ValueKey('location')),
      'notification_permission' =>
        const NotificationPermissionScreen(key: ValueKey('notification')),
      'usage_guide' => const UsageGuideScreen(key: ValueKey('usage_guide')),
      'referral_code' =>
        const ReferralCodeScreen(key: ValueKey('referral_code')),
      'app' => const MainScreen(key: ValueKey('app')),
      _ => const MainScreen(key: ValueKey('app')),
    };
  }

  /// 로그인 플로우 위에 쌓인 라우트(인증번호 화면 등) 또는 로그아웃 시 잔여 라우트 정리
  void _clearStaleRoutesIfNeeded(String stage) {
    final prev = _previousStage;
    _previousStage = stage;
    if (prev == null) return;

    final leavingLogin = prev == 'login' && stage != 'login';
    final loggedOut = stage == 'login' && prev != 'login';
    if (!leavingLogin && !loggedOut) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    });
  }
}
