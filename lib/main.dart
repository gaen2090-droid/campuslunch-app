import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/notification_permission_screen.dart';
import 'screens/owner_screen.dart';
import 'screens/admin_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const CampusLunchApp(),
    ),
  );
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
          seedColor: const Color(0xFFFF6207),
          brightness: Brightness.light,
        ),
        fontFamily: 'Pretendard',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF9F7),
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
        'app' => const MainScreen(key: ValueKey('app')),
        'owner' => const OwnerScreen(key: ValueKey('owner')),
        'admin' => const AdminScreen(key: ValueKey('admin')),
        _ => const MainScreen(key: ValueKey('app')),
      },
    );
  }
}
