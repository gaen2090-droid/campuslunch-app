import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 회원가입 완료 후, 홈 진입 직전 — 추천인 코드 입력(선택)
class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key});

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final code =
          await context.read<AppProvider>().peekReferralCodeFromInviteLink();
      if (!mounted || code == null || code.isEmpty) return;
      _controller.text = code;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err =
        await context.read<AppProvider>().submitReferralCode(_controller.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _skip() async {
    if (_loading) return;
    setState(() => _loading = true);
    await context.read<AppProvider>().skipReferralPrompt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '추천인 코드',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF000000),
                  letterSpacing: -0.8,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '친구의 추천인 코드를 입력해주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                enabled: !_loading,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '추천인 코드 입력 (선택)',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  errorText: _error,
                  errorMaxLines: 2,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF000000),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const Spacer(),
              GestureDetector(
                onTap: !_loading ? _submit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: !_loading ? _skip : null,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
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
