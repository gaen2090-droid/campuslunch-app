import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class OwnerVerifySheet extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<int> onSuccess;

  const OwnerVerifySheet({
    super.key,
    required this.onClose,
    required this.onSuccess,
  });

  @override
  State<OwnerVerifySheet> createState() => _OwnerVerifySheetState();
}

class _OwnerVerifySheetState extends State<OwnerVerifySheet> {
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
      widget.onSuccess(0);
    } else {
      setState(() {
        _errorCode = error;
        _status = 'error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        widget.onClose();
      },
      child: Container(
        color: Colors.black.withAlpha(77),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Material(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, safeBottom + 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                  width: 40,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '사장님 인증',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),

                if (_status == 'success') ...[
                  Container(
                    margin: const EdgeInsets.only(top: 24),
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
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '관리자에게 받은 6자리 인증번호를 입력해주세요.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
