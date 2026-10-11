import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// 앱 진입 시 스토어에 새 버전이 있으면 업데이트를 권장한다 (강제 아님).
/// - Android: Google Play In-App Update(flexible) 시스템 팝업. Play 스토어로 설치된 앱에서만 동작.
/// - iOS: App Store 조회(iTunes lookup)로 버전을 비교해 팝업을 띄우고 스토어로 연결.
/// 사용자가 "나중에"를 누르면 [_snooze] 동안은 다시 묻지 않는다.
class AppUpdateService {
  AppUpdateService._();

  static const _bundleId = 'com.campuslunch.app';
  static const _snoozeKey = 'app_update_prompt_snoozed_until_ms';
  static const _snooze = Duration(hours: 24);

  static bool _checkedThisSession = false;

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (kIsWeb || _checkedThisSession) return;
    _checkedThisSession = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_snoozeKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < until) return;
      if (!context.mounted) return;

      if (Platform.isAndroid) {
        await _checkAndroid(context, prefs);
      } else if (Platform.isIOS) {
        await _checkIos(context, prefs);
      }
    } catch (e) {
      // 업데이트 확인 실패는 앱 사용에 영향을 주면 안 된다.
      debugPrint('[AppUpdate] check failed: $e');
    }
  }

  static Future<void> _snoozeNow(SharedPreferences prefs) => prefs.setInt(
        _snoozeKey,
        DateTime.now().add(_snooze).millisecondsSinceEpoch,
      );

  // ── Android ──────────────────────────────────────────────────────────────
  static Future<void> _checkAndroid(
      BuildContext context, SharedPreferences prefs) async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable ||
        !info.flexibleUpdateAllowed) {
      return;
    }

    final result = await InAppUpdate.startFlexibleUpdate();
    if (result == AppUpdateResult.userDeniedUpdate) {
      await _snoozeNow(prefs);
      return;
    }
    if (result != AppUpdateResult.success) return;

    // 백그라운드 다운로드가 끝나면 재시작해서 설치할지 묻는다.
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    StreamSubscription<InstallStatus>? sub;
    sub = InAppUpdate.installUpdateListener.listen((status) {
      if (status != InstallStatus.downloaded) return;
      sub?.cancel();
      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(days: 1),
          content: Text('업데이트 준비가 끝났어요'),
          action: SnackBarAction(
            label: '재시작',
            onPressed: InAppUpdate.completeFlexibleUpdate,
          ),
        ),
      );
    });
  }

  // ── iOS ──────────────────────────────────────────────────────────────────
  static Future<void> _checkIos(
      BuildContext context, SharedPreferences prefs) async {
    final res = await http
        .get(Uri.parse(
            'https://itunes.apple.com/lookup?bundleId=$_bundleId&country=kr'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return;

    final results = (jsonDecode(res.body) as Map)['results'] as List?;
    if (results == null || results.isEmpty) return;
    final store = results.first as Map;
    final storeVersion = store['version'] as String?;
    final storeUrl = store['trackViewUrl'] as String?;
    if (storeVersion == null || storeUrl == null) return;

    final current = (await PackageInfo.fromPlatform()).version;
    if (!_isNewer(storeVersion, current)) return;
    if (!context.mounted) return;

    final go = await _showUpdateDialog(context);

    if (go == true) {
      await launchUrl(Uri.parse(storeUrl),
          mode: LaunchMode.externalApplication);
    } else {
      await _snoozeNow(prefs);
    }
  }

  static Future<bool?> _showUpdateDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '새 버전이 나왔어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '더 좋아진 캠퍼스런치를 사용해보세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: '나중에',
                      background: const Color(0xFFF3F4F6),
                      foreground: const Color(0xFF6B7280),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DialogButton(
                      label: '업데이트',
                      background: AppColors.primaryCta,
                      foreground: Colors.white,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "1.0.10" > "1.0.9" 같은 점(.) 구분 숫자 버전 비교.
  static bool _isNewer(String store, String current) {
    List<int> parse(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final a = parse(store);
    final b = parse(current);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
