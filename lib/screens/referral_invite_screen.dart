import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_links.dart';
import '../providers/app_provider.dart';

/// 마이페이지 > "친구 초대하고 함께 스탬프 받기"
class ReferralInviteScreen extends StatefulWidget {
  const ReferralInviteScreen({super.key});

  @override
  State<ReferralInviteScreen> createState() => _ReferralInviteScreenState();
}

class _ReferralInviteScreenState extends State<ReferralInviteScreen> {
  final _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMyReferralHistory();
    });
  }

  static String _shareBody(String code) =>
      '중앙대생 필수 앱 캠퍼스런치!\n'
      '지금 바로 갈 수 있는 식당을 알 수 있다고? 🧚🏻‍♀️\n\n'
      '스탬프 모아서 아메리카노 쿠폰도 받아봐 ☕️\n'
      '친구 추천으로 가입하면 둘 다 스탬프 3개 지급 🎉\n\n'
      '추천인 코드: $code';

  /// 카톡 미설치 등 — 시스템 공유 폴백
  static String shareMessage(String code) {
    return '${_shareBody(code)}\n\n${AppLinks.inviteUrl(code)}';
  }

  Rect? _shareOrigin() {
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareViaSystem(String code) async {
    await Share.share(
      shareMessage(code),
      subject: '캠퍼스런치 친구 초대',
      sharePositionOrigin: _shareOrigin(),
    );
  }

  /// 카카오톡 카드 + 「앱에서 열기」 버튼 → kakaolink 스킴으로 앱 실행
  Future<void> _share() async {
    final code = context.read<AppProvider>().myReferralCode;
    if (code.isEmpty) return;

    final inviteUri = Uri.parse(AppLinks.inviteUrl(code));
    final params = AppLinks.inviteExecutionParams(code);
    final link = Link(
      webUrl: inviteUri,
      mobileWebUrl: inviteUri,
      androidExecutionParams: params,
      iosExecutionParams: params,
    );
    final template = TextTemplate(
      text: _shareBody(code),
      link: link,
      buttons: [
        Button(title: '앱에서 열기', link: link),
      ],
    );

    try {
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
        return;
      }
      await _shareViaSystem(code);
    } catch (e) {
      debugPrint('[ReferralInvite] Kakao share failed: $e');
      try {
        await _shareViaSystem(code);
      } catch (e2) {
        debugPrint('[ReferralInvite] Share.share failed: $e2');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유를 열지 못했어요. 잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _copyCode(String code) async {
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '친구 초대',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: _shareButtonKey,
                  onTap: code.isEmpty ? null : _share,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: 56,
                    decoration: BoxDecoration(
                      color: code.isEmpty
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: code.isEmpty
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withAlpha(60),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.share_rounded,
                          size: 18,
                          color: code.isEmpty
                              ? const Color(0xFF9CA3AF)
                              : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '초대장 공유하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: code.isEmpty
                                ? const Color(0xFF9CA3AF)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
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
            const Flexible(
              child: Text(
                '초대한 친구',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF000000),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF000000),
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
            color: Color(0xFF000000),
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
                  color: Color(0xFF000000),
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
                    Icon(Icons.copy_rounded, size: 15, color: Color(0xFF000000)),
                    SizedBox(width: 6),
                    Text(
                      '복사',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
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
