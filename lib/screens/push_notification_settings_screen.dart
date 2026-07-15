import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class PushNotificationSettingsScreen extends StatefulWidget {
  const PushNotificationSettingsScreen({super.key});

  @override
  State<PushNotificationSettingsScreen> createState() =>
      _PushNotificationSettingsScreenState();
}

class _PushNotificationSettingsScreenState
    extends State<PushNotificationSettingsScreen> {
  late bool _lunchPush;
  late bool _communityPush;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final provider = context.read<AppProvider>();
      _lunchPush = provider.lunchPushEnabled;
      _communityPush = provider.communityCommentsPushEnabled;
    }
  }

  Future<void> _snack(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      backgroundColor: const Color(0xFF9ECA8B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(milliseconds: 1600),
      elevation: 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '푸시 알림 설정',
          style: TextStyle(
            fontFamily: 'OkDanDan',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          children: [
            _ToggleRow(
              title: '점심 피크 추천 알림',
              desc: '점심 피크 시간에 여유로운 매장을 알려드려요.',
              enabled: _lunchPush,
              onToggle: () async {
                final next = !_lunchPush;
                setState(() => _lunchPush = next);
                await context.read<AppProvider>().setLunchPush(next);
                if (next) await _snack('점심 피크 알림을 켰어요.');
              },
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _ToggleRow(
              title: '커뮤니티 댓글 알림',
              desc: '글 상단의 알림 버튼을 켜두면, 댓글이 달렸을 때 알려드려요.',
              enabled: _communityPush,
              onToggle: () async {
                final next = !_communityPush;
                setState(() => _communityPush = next);
                await context.read<AppProvider>().setCommunityCommentsPush(next);
                if (next) await _snack('커뮤니티 댓글 알림을 켰어요.');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String desc;
  final bool enabled;
  final VoidCallback onToggle;

  const _ToggleRow({
    required this.title,
    required this.desc,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: enabled,
            activeColor: const Color(0xFF5E8C4A),
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}
