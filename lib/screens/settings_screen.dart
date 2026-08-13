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
  bool _showEditSheet = false;
  String _editNickname = '';
  final _nicknameCtrl = TextEditingController();

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _openEdit(String current) {
    _nicknameCtrl.value = TextEditingValue(
      text: current,
      selection: TextSelection.collapsed(offset: current.length),
    );
    setState(() {
      _editNickname = current;
      _showEditSheet = true;
    });
  }

  Future<void> _saveNickname() async {
    final trimmed = _editNickname.trim();
    if (trimmed.isEmpty) {
      setState(() => _showEditSheet = false);
      return;
    }
    final err = await context.read<AppProvider>().updateNickname(trimmed);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    setState(() => _showEditSheet = false);
  }

  void _confirmWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('회원 탈퇴', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '계정과 프로필이 삭제되며 복구할 수 없어요.\n'
          '카카오 로그인 계정은 카카오 연결도 해제됩니다.\n\n'
          '탈퇴 후 30일간은 같은 계정으로 재가입할 수 없어요.',
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
              size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '설정',
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
        ListView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
        children: [
          if (!provider.hasOwnerTab)
            GestureDetector(
              onTap: () => _openEdit(provider.nickname),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    const Text(
                      '내 닉네임',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.nickname.isEmpty ? '앙대 학생' : provider.nickname,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_forward_ios,
                        size: 12, color: Color(0xFF9CA3AF)),
                  ],
                ),
              ),
            ),
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
                      color: Color(0xFF000000),
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
                      color: Color(0xFF000000),
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
          if (!provider.hasOwnerTab) ...[
            _SettingsButton(
              label: '알림 설정',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PushNotificationSettingsScreen()),
              ),
            ),
            const SizedBox(height: 8),
          ],
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

        // ── 닉네임 수정 시트 ──
        if (_showEditSheet)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showEditSheet = false),
              child: Container(
                color: Colors.black.withAlpha(76),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {}, // absorb taps
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        padding: EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            MediaQuery.of(context).padding.bottom +
                                MediaQuery.of(context).viewInsets.bottom +
                                24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '닉네임 수정',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF000000)),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      autofocus: true,
                                      controller: _nicknameCtrl,
                                      onChanged: (v) {
                                        if (v.length > 20) {
                                          _nicknameCtrl.value =
                                              TextEditingValue(
                                            text: v.substring(0, 20),
                                            selection:
                                                const TextSelection.collapsed(
                                                    offset: 20),
                                          );
                                        }
                                        setState(() =>
                                            _editNickname = _nicknameCtrl.text);
                                      },
                                      onSubmitted: (_) => _saveNickname(),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937)),
                                      decoration: const InputDecoration(
                                        hintText: '닉네임을 입력하세요',
                                        hintStyle: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF9CA3AF)),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_editNickname.length}/20',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFD1D5DB)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: '※ 닉네임을 설정하면 ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '30일간 변경할 수 없습니다.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _showEditSheet = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '취소',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF374151)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _editNickname.trim().isEmpty
                                        ? null
                                        : _saveNickname,
                                    child: AnimatedOpacity(
                                      opacity: _editNickname.trim().isEmpty
                                          ? 0.3
                                          : 1.0,
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF26BC7D),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '저장',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                  color: textColor ?? const Color(0xFF000000),
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
