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
  late bool _rewardPush;
  late bool _newsPush;
  late bool _communityPush;
  bool _marketingConsent = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final provider = context.read<AppProvider>();
      _lunchPush = provider.lunchPushEnabled;
      _rewardPush = provider.rewardPushEnabled;
      _newsPush = provider.newsPushEnabled;
      _communityPush = provider.communityCommentsPushEnabled;
      _loadMarketingConsent();
    }
  }

  Future<void> _loadMarketingConsent() async {
    final agreed = await context.read<AppProvider>().fetchMarketingConsent();
    if (!mounted) return;
    setState(() => _marketingConsent = agreed);
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
          '알림 설정',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('서비스 알림'),
            _ToggleRow(
              title: '점심시간 알림',
              desc: '점심시간에 캠퍼스런치 이용을 알려드려요.',
              enabled: _lunchPush,
              onToggle: () async {
                final next = !_lunchPush;
                setState(() => _lunchPush = next);
                await context.read<AppProvider>().setLunchPush(next);
              },
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _ToggleRow(
              title: '리워드 지급 알림',
              desc: '기프티콘이 지급되면 알려드려요.',
              enabled: _rewardPush,
              onToggle: () async {
                final next = !_rewardPush;
                setState(() => _rewardPush = next);
                await context.read<AppProvider>().setRewardPush(next);
              },
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _ToggleRow(
              title: '캠퍼스런치 소식 알림',
              desc: '업데이트, 이벤트 등 운영 소식을 알려드려요.',
              enabled: _newsPush,
              onToggle: () async {
                final next = !_newsPush;
                setState(() => _newsPush = next);
                await context.read<AppProvider>().setNewsPush(next);
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader('커뮤니티'),
            _ToggleRow(
              title: '댓글 알림',
              desc: '글 상단의 알림 버튼을 켜두면, 댓글이 달렸을 때 알려드려요.',
              enabled: _communityPush,
              onToggle: () async {
                final next = !_communityPush;
                setState(() => _communityPush = next);
                await context.read<AppProvider>().setCommunityCommentsPush(next);
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader('서비스 동의'),
            _ToggleRow(
              title: '개인정보 활용 및 마케팅 정보 수신',
              desc: '마케팅 및 프로모션 활동에 대한 개인정보 활용에 동의해요.',
              enabled: _marketingConsent,
              onToggle: () async {
                final next = !_marketingConsent;
                setState(() => _marketingConsent = next);
                await context.read<AppProvider>().setMarketingConsent(next);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF9CA3AF),
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
