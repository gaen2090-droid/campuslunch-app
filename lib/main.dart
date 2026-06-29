import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/env.dart';
import 'providers/app_provider.dart';
import 'services/google_auth_service.dart';
import 'services/kakao_auth_service.dart';
import 'services/kakao_map_bootstrap.dart';
import 'services/push_notification_service.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/notification_permission_screen.dart';
import 'screens/usage_guide_screen.dart';
import 'navigation/app_route_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[Env] .env load failed, using native_keys.json fallback: $e');
  }
  await Env.loadReleaseConfig();

  await KakaoAuthService.initialize();

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

  late final AppProvider appProvider;
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        appProvider = AppProvider()..init();
        return appProvider;
      },
      child: const CampusLunchApp(),
    ),
  );

  // 첫 프레임 이후 무거운 네이티브 초기화 (스플래시·흰 화면 지연 방지)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_deferredStartup(appProvider));
  });
}

Future<void> _deferredStartup(AppProvider provider) async {
  unawaited(GoogleAuthService.initialize());
  unawaited(KakaoMapBootstrap.ensureInitialized());
  try {
    await PushNotificationService.instance.initialize(
      onOpenHome: (_) => provider.openHomeFromPush(),
    );
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
          seedColor: const Color(0xFF5E8C4A),
          brightness: Brightness.light,
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
      home: const _Root(),
      navigatorObservers: [appRouteObserver],
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AppProvider>().stage;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (stage) {
        'splash' => const SplashScreen(key: ValueKey('splash')),
        'onboarding' =>
          const OnboardingScreen(key: ValueKey('onboarding')),
        'login' => const LoginScreen(key: ValueKey('login')),
        'location_permission' =>
          const LocationPermissionScreen(key: ValueKey('location')),
        'notification_permission' =>
          const NotificationPermissionScreen(key: ValueKey('notification')),
        'usage_guide' => const UsageGuideScreen(key: ValueKey('usage_guide')),
        'app' => const MainScreen(key: ValueKey('app')),
        _ => const MainScreen(key: ValueKey('app')),
      },
    );
  }
}
