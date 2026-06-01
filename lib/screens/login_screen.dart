import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _cfCtrl = TextEditingController();
  bool _showPw = false;
  bool _showCf = false;
  String _error = '';
  bool _loading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _cfCtrl.dispose();
    super.dispose();
  }

  void _switchTab(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
      _error = '';
      _pwCtrl.clear();
      _cfCtrl.clear();
      _showPw = false;
      _showCf = false;
    });
  }

  Future<void> _submit() async {
    final email = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty) { setState(() => _error = '이메일을 입력해주세요.'); return; }
    if (!_isLogin && !email.contains('@')) {
      setState(() => _error = '이메일 형식으로 입력해주세요.'); return;
    }
    if (pw.length < 6) { setState(() => _error = '비밀번호는 6자 이상이어야 해요.'); return; }

    setState(() { _loading = true; _error = ''; });
    final provider = context.read<AppProvider>();

    if (_isLogin) {
      final ok = await provider.login(email, pw);
      if (!ok && mounted) setState(() { _error = '이메일 또는 비밀번호가 올바르지 않아요.'; _loading = false; });
    } else {
      final cf = _cfCtrl.text;
      if (pw != cf) { setState(() { _error = '비밀번호가 일치하지 않아요.'; _loading = false; }); return; }
      final err = await provider.register(email, pw, '');
      if (err != null && mounted) setState(() { _error = err; _loading = false; });
    }
  }

  void _socialLogin() => context.read<AppProvider>().socialLogin();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            right: -80, top: 60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 240, height: 240,
                decoration: const BoxDecoration(color: Color(0xFFBBF7D0), shape: BoxShape.circle),
              ),
            ),
          ),
          Positioned(
            left: -100, bottom: 80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                    color: const Color(0xFFA7F3D0).withAlpha(180), shape: BoxShape.circle),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '편리한 이용을 위해\n로그인이 필요해요',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      height: 1.25,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 탭 스위처
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _TabBtn(label: '로그인', active: _isLogin, onTap: () => _switchTab(true)),
                        _TabBtn(label: '회원가입', active: !_isLogin, onTap: () => _switchTab(false)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 입력 필드
                  _Field(
                    controller: _idCtrl,
                    hint: '이메일',
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  const SizedBox(height: 10),
                  _PasswordField(
                    controller: _pwCtrl,
                    hint: '비밀번호 (6자 이상)',
                    show: _showPw,
                    onToggle: () => setState(() => _showPw = !_showPw),
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 10),
                    _PasswordField(
                      controller: _cfCtrl,
                      hint: '비밀번호 확인',
                      show: _showCf,
                      onToggle: () => setState(() => _showCf = !_showCf),
                      onChanged: (_) => setState(() => _error = ''),
                    ),
                  ],

                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 로그인/가입 버튼
                  GestureDetector(
                    onTap: _loading ? null : _submit,
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                _isLogin ? '로그인' : '가입하기',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 구분선
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '간편 로그인',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9CA3AF)),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 카카오
                  GestureDetector(
                    onTap: _socialLogin,
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE500),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned(
                            left: 16,
                            child: _KakaoIcon(),
                          ),
                          Text(
                            '카카오로 ${_isLogin ? '계속하기' : '시작하기'}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF191919)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 구글
                  GestureDetector(
                    onTap: _socialLogin,
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFDADCE0)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned(left: 16, child: _GoogleIcon()),
                          Text(
                            'Google로 ${_isLogin ? '계속하기' : '시작하기'}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF3C4043)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: active ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  const _Field({required this.controller, required this.hint, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool show;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  const _PasswordField(
      {required this.controller, required this.hint, required this.show, required this.onToggle, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !show,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFF9CA3AF)),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
      ),
    );
  }
}

class _KakaoIcon extends StatelessWidget {
  const _KakaoIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      decoration: const BoxDecoration(color: Color(0xFF191919), shape: BoxShape.circle),
      child: const Center(child: Text('K', style: TextStyle(color: Color(0xFFFEE500), fontSize: 11, fontWeight: FontWeight.w900))),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDADCE0)), shape: BoxShape.circle),
      child: const Center(child: Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 11, fontWeight: FontWeight.w900))),
    );
  }
}
