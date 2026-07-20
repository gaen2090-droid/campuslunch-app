import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/email_auth.dart';
import '../providers/app_provider.dart';
import '../widgets/keyboard_safe.dart';

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
  String _error = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    void clearError() { if (_error.isNotEmpty) setState(() => _error = ''); }
    _idCtrl.addListener(clearError);
    _pwCtrl.addListener(clearError);
    _cfCtrl.addListener(clearError);
  }

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
      if (!ok && mounted) setState(() {
        _error = '이메일 또는 비밀번호가 올바르지 않아요.\n'
            '가입 후 이메일 인증번호 입력을 완료했는지 확인해주세요.';
        _loading = false;
      });
    } else {
      final cf = _cfCtrl.text;
      if (pw != cf) { setState(() { _error = '비밀번호가 일치하지 않아요.'; _loading = false; }); return; }
      final err = await provider.register(email, pw, '');
      if (!mounted) return;
      setState(() => _loading = false);
      if (err == 'pending_email') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _EmailVerifyScreen(email: email),
          ),
        );
      } else if (err != null) {
        setState(() => _error = err);
      }
    }
  }

  Future<void> _loginWithKakao() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final err = await context.read<AppProvider>().loginWithKakao();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err != null) _error = err;
    });
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final err = await context.read<AppProvider>().loginWithGoogle();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err != null) _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: KeyboardDismissScroll(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '편리한 이용을 위해\n로그인이 필요해요',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
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
                  ),
                  const SizedBox(height: 10),
                  _PasswordField(
                    controller: _pwCtrl,
                    hint: '비밀번호 (6자 이상)',
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 10),
                    _PasswordField(
                      controller: _cfCtrl,
                      hint: '비밀번호 확인',
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
                        color: const Color(0xFF9ECA8B),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF111827), strokeWidth: 2))
                            : Text(
                                _isLogin ? '로그인' : '가입하기',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827)),
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
                    onTap: _loading ? null : _loginWithKakao,
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

                  // Google
                  GestureDetector(
                    onTap: _loading ? null : _loginWithGoogle,
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
  const _Field({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
            borderSide: const BorderSide(color: Color(0xFF5E8C4A), width: 1.5)),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const _PasswordField({required this.controller, required this.hint});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_show,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _show = !_show),
          child: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
            borderSide: const BorderSide(color: Color(0xFF5E8C4A), width: 1.5)),
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

class _EmailVerifyScreen extends StatefulWidget {
  final String email;
  const _EmailVerifyScreen({required this.email});

  @override
  State<_EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<_EmailVerifyScreen> {
  final _otpCtrl = TextEditingController();
  bool _resending = false;
  bool _verifying = false;
  String? _resendMsg;
  String? _error;
  bool _verified = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _resendMsg = null;
      _error = null;
    });
    final err =
        await context.read<AppProvider>().resendSignupEmail(widget.email);
    if (!mounted) return;
    setState(() {
      _resending = false;
      _resendMsg = err ?? '인증번호를 다시 보냈어요.';
    });
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    final err = await context.read<AppProvider>()
        .verifySignupOtp(widget.email, _otpCtrl.text);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      if (err != null) {
        _error = err;
      } else {
        _verified = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final stage = context.read<AppProvider>().stage;
          if (stage == 'legal_terms_consent' ||
              stage == 'app' ||
              stage == 'usage_guide') {
            _finish();
          }
        });
      }
    });
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: KeyboardDismissScroll(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F8F0),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Icon(Icons.pin_outlined,
                        size: 36, color: Color(0xFF5E8C4A)),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '인증번호를 입력해주세요',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.email}\n으로 ${emailSignupOtpLength}자리 인증번호를 보냈어요.\n'
                  '메일에 적힌 번호를 아래에 입력하면 가입이 완료돼요.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _otpCtrl,
                  enabled: !_verified && !_verifying,
                  keyboardType: TextInputType.number,
                  maxLength: emailSignupOtpLength,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _error = null),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 12,
                    color: Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    hintText: List.filled(emailSignupOtpLength, '0').join(),
                    hintStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      color: Color(0xFFD1D5DB),
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF5E8C4A), width: 1.5),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
                if (_resendMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _resendMsg!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _resendMsg!.contains('실패') ||
                              _resendMsg!.contains('없')
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF5E8C4A),
                    ),
                  ),
                ],
                if (_verified) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '이메일 인증이 완료됐어요!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5E8C4A),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (!_verified) ...[
                  GestureDetector(
                    onTap: (_verifying ||
                            _otpCtrl.text.length != emailSignupOtpLength)
                        ? null
                        : _verify,
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: (_verifying ||
                                _otpCtrl.text.length != emailSignupOtpLength)
                            ? const Color(0xFFBFE0B0)
                            : const Color(0xFF9ECA8B),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: _verifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF111827)))
                            : const Text(
                                '인증하기',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _resending ? null : _resend,
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Center(
                        child: _resending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text(
                                '인증번호 다시 받기',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF374151),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
                GestureDetector(
                  onTap: _verified ? _finish : () => Navigator.pop(context),
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _verified
                          ? const Color(0xFF9ECA8B)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        _verified ? '시작하기' : '로그인 화면으로',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _verified
                              ? const Color(0xFF111827)
                              : const Color(0xFF374151),
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
