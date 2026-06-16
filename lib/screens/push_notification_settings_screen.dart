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
  bool _lunchPush = false;
  bool _dinnerPush = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final provider = context.read<AppProvider>();
      _lunchPush = provider.lunchPushEnabled;
      _dinnerPush = provider.dinnerPushEnabled;
    }
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
        title: const Text(
          '푸시 알림 설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 1)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              _ToggleRow(
                title: '점심 피크 추천 알림',
                desc: '평일 12:00에 여유로운 매장을 알려드려요!',
                enabled: _lunchPush,
                onToggle: () async {
                  final next = !_lunchPush;
                  setState(() => _lunchPush = next);
                  await context.read<AppProvider>().setLunchPush(next);
                  if (!context.mounted) return;
                  if (next) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text(
                        '평일 12:00에 알림을 보내드릴게요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF111827),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      duration: const Duration(milliseconds: 1600),
                      elevation: 0,
                    ));
                  }
                },
              ),
              const Divider(color: Color(0xFFE5E7EB), height: 1),
              _ToggleRow(
                title: '저녁 피크 추천 알림',
                desc: '평일 18:00에 여유로운 매장을 알려드려요!',
                enabled: _dinnerPush,
                onToggle: () async {
                  final next = !_dinnerPush;
                  setState(() => _dinnerPush = next);
                  await context.read<AppProvider>().setDinnerPush(next);
                  if (!context.mounted) return;
                  if (next) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text(
                        '평일 18:00에 알림을 보내드릴게요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF111827),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      duration: const Duration(milliseconds: 1600),
                      elevation: 0,
                    ));
                  }
                },
              ),
            ],
          ),
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color:
                    enabled ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
