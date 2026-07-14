import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import 'push_notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _confirmWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('회원 탈퇴', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '계정과 프로필이 삭제되며 복구할 수 없어요.\n'
          '카카오 로그인 계정은 카카오 연결도 해제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await context.read<AppProvider>().withdrawAccount();
              if (!context.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
                return;
              }
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('탈퇴하기',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _loginMethodLabel() {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return '';
    final authProvider = user.appMetadata['provider'] as String?;
    return switch (authProvider) {
      'kakao' => '카카오 로그인',
      'google' => '구글 로그인',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final email = SupabaseService.client.auth.currentUser?.email ?? '';
    final loginMethod = _loginMethodLabel();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
        children: [
          if (email.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Text(
                    '내 아이디',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (loginMethod.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Text(
                    '연동된 서비스',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    loginMethod,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _SettingsButton(
            label: '푸시 알림 설정',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PushNotificationSettingsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              provider.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '로그아웃',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => _confirmWithdraw(context),
              child: const Text(
                '회원 탈퇴',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final bool showArrow;

  const _SettingsButton({
    required this.label,
    required this.onTap,
    this.textColor,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? const Color(0xFF111827),
                ),
              ),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}
