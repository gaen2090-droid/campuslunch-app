import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';

/// 마이페이지 > "친구 초대하고 함께 스탬프 받기"
class ReferralInviteScreen extends StatefulWidget {
  const ReferralInviteScreen({super.key});

  @override
  State<ReferralInviteScreen> createState() => _ReferralInviteScreenState();
}

class _ReferralInviteScreenState extends State<ReferralInviteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMyReferralHistory();
    });
  }

  String _shareMessage(String code) {
    return '중앙대생 필수 앱 캠퍼스런치!\n'
        '지금 바로 갈 수 있는 식당을 알 수 있다고? 🧚🏻‍♀️\n\n'
        '스탬프 모아서 아메리카노 쿠폰도 받아봐 ☕️\n'
        '친구 추천으로 가입하면 둘 다 스탬프 3개 지급 🎉\n\n'
        '추천인 코드: $code';
  }

  Future<void> _share() async {
    final code = context.read<AppProvider>().myReferralCode;
    if (code.isEmpty) return;
    await Share.share(_shareMessage(code));
  }

  Future<void> _copyCode(String code) async {
    // Android 13+/iOS는 클립보드 복사 시 시스템이 자체 토스트를 띄우므로
    // 앱에서 별도 안내를 띄우면 중복된다.
    await Clipboard.setData(ClipboardData(text: code));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final code = provider.myReferralCode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '친구 초대',
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/referral_invite_banner.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),

                const SizedBox(height: 8),
                Container(height: 8, color: const Color(0xFFF3F4F6)),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: _MyReferralCodeSection(
                    code: code,
                    onCopy: code.isEmpty ? null : () => _copyCode(code),
                  ),
                ),

                Container(height: 8, color: const Color(0xFFF3F4F6)),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _InvitedFriendsSection(
                    count: provider.totalReferrerEventCount,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: code.isEmpty ? null : _share,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: code.isEmpty
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFF5E8C4A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: code.isEmpty
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF5E8C4A).withAlpha(60),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share_rounded,
                          size: 18,
                          color: code.isEmpty ? const Color(0xFF9CA3AF) : Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '초대장 공유하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: code.isEmpty ? const Color(0xFF9CA3AF) : Colors.white,
                        ),
                      ),
                    ],
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

class _InvitedFriendsSection extends StatelessWidget {
  final int count;
  const _InvitedFriendsSection({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '초대한 친구',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5E8C4A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '가입을 완료하면 스탬프가 지급돼요',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

class _MyReferralCodeSection extends StatelessWidget {
  final String code;
  final VoidCallback? onCopy;

  const _MyReferralCodeSection({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내 추천인 코드',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                code.isEmpty ? '불러오는 중...' : code,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: 2,
                ),
              ),
            ),
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 15, color: Color(0xFF5E8C4A)),
                    SizedBox(width: 6),
                    Text(
                      '복사',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5E8C4A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
