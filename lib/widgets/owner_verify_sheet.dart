import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class OwnerVerifyScreen extends StatefulWidget {
  const OwnerVerifyScreen({super.key});

  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OwnerVerifyScreen()),
    );
  }

  @override
  State<OwnerVerifyScreen> createState() => _OwnerVerifyScreenState();
}

class _OwnerVerifyScreenState extends State<OwnerVerifyScreen> {
  final _ctrl = TextEditingController();
  String _status = 'idle'; // idle | loading | success | error
  String _errorCode = 'INVALID_CODE';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.length != 6) return;
    setState(() => _status = 'loading');
    final error = await context.read<AppProvider>().verifyOwnerCode(_ctrl.text.trim());
    if (!mounted) return;
    if (error == null) {
      setState(() => _status = 'success');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorCode = error;
        _status = 'error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          '사장님 인증',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status == 'success') ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Text('🎉', style: TextStyle(fontSize: 32)),
                    SizedBox(height: 12),
                    Text(
                      '사장님 인증이 완료되었어요.\n이제 내 매장의 혼잡도를 직접 반영할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.6,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                '관리자에게 받은 6자리 인증번호를 입력해주세요.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() => _status = 'idle'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Color(0xFFD1D5DB),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                    borderSide: const BorderSide(color: Color(0xFF5E8C4A), width: 1.5),
                  ),
                ),
              ),
              if (_status == 'error') ...[
                const SizedBox(height: 8),
                Text(
                  _errorCode == 'ALREADY_USED'
                      ? '이미 사용된 인증번호예요.\n관리자에게 문의해주세요.'
                      : _errorCode == 'LOGIN_REQUIRED'
                          ? '로그인 후 인증해주세요.\n계정으로 로그인한 뒤 다시 시도해주세요.'
                          : '인증번호가 일치하지 않아요.\n다시 확인해주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Opacity(
                opacity: _ctrl.text.length == 6 ? 1.0 : 0.4,
                child: GestureDetector(
                  onTap: (_ctrl.text.length == 6 && _status != 'loading') ? _submit : null,
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9ECA8B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _status == 'loading'
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFF111827),
                                strokeWidth: 2,
                              ),
                            )
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
