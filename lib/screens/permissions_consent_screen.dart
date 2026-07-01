import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../constants/app_permissions.dart';
import '../providers/app_provider.dart';
import '../widgets/rice_ball_icon.dart';

/// 첫 앱 실행 시 — 기기 권한 안내 (OS 권한은 확인 버튼 시점)
class PermissionsConsentScreen extends StatefulWidget {
  const PermissionsConsentScreen({super.key});

  @override
  State<PermissionsConsentScreen> createState() =>
      _PermissionsConsentScreenState();
}

class _PermissionsConsentScreenState extends State<PermissionsConsentScreen> {
  bool _loading = false;
  bool _locationBlocked = false;

  Future<void> _confirm() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _locationBlocked = false;
    });

    final ok =
        await context.read<AppProvider>().completePermissionsConsent();

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) _locationBlocked = true;
    });
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_locationBlocked) {
      return _LocationBlockedView(
        loading: _loading,
        onRetry: _confirm,
        onOpenSettings: _openSettings,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F0),
      body: Stack(
        children: [
          Positioned(
            right: -90,
            top: 40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 70,
                sigmaY: 70,
                tileMode: TileMode.decal,
              ),
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E6BA),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9ECA8B),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFFC8E6BA),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: RiceBallIcon(size: 36),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          AppPermissions.introTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            height: 1.2,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          AppPermissions.introBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ...AppPermissions.permissionCards.map(
                          (card) => _PermissionHeroCard(card: card),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            '위치·주변 기기(Android) 권한은 필수입니다. '
                            '알림은 선택이며, 거부해도 앱을 이용할 수 있어요.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomBar(
                  loading: _loading,
                  onConfirm: _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationBlockedView extends StatelessWidget {
  const _LocationBlockedView({
    required this.loading,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool loading;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.location_off_outlined,
                  size: 40,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                AppPermissions.blockedTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                AppPermissions.blockedBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.65,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: loading ? null : onOpenSettings,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      '설정에서 권한 허용하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: loading ? null : onRetry,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9ECA8B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF111827),
                            ),
                          )
                        : const Text(
                            '다시 시도',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionHeroCard extends StatelessWidget {
  const _PermissionHeroCard({required this.card});

  final AppPermissionCard card;

  @override
  Widget build(BuildContext context) {
    final isRequired = card.badge == '필수';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRequired ? const Color(0xFFDAFFCA) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(card.icon, color: const Color(0xFF5E8C4A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isRequired
                            ? const Color(0xFFDAFFCA)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        card.badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isRequired
                              ? const Color(0xFF4C9C2A)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  card.body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.loading,
    required this.onConfirm,
  });

  final bool loading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          const Text(
            AppPermissions.confirmHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: loading ? null : onConfirm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: loading
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF9ECA8B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: loading
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0xFFC8E6BA),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF111827),
                        ),
                      )
                    : const Text(
                        AppPermissions.confirmLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
