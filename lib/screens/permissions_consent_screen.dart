import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class PermissionsConsentScreen extends StatefulWidget {
  const PermissionsConsentScreen({super.key});

  @override
  State<PermissionsConsentScreen> createState() => _PermissionsConsentScreenState();
}

class _PermissionsConsentScreenState extends State<PermissionsConsentScreen> {
  bool _location = false;
  bool _nearby = false;
  bool _marketing = false;
  bool _loading = false;
  bool _locationBlocked = false;

  bool get _allRequired => _location && _nearby;
  bool get _allChecked => _location && _nearby && _marketing;

  void _toggleAll(bool v) => setState(() {
        _location = v;
        _nearby = v;
        _marketing = v;
      });

  Future<void> _confirm() async {
    if (!_allRequired || _loading) return;
    setState(() { _loading = true; _locationBlocked = false; });
    final ok = await context.read<AppProvider>().completePermissionsConsent();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) _locationBlocked = true;
    });
  }

  Future<void> _openSettings() async => Geolocator.openAppSettings();

  @override
  Widget build(BuildContext context) {
    if (_locationBlocked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.location_off_outlined, size: 52, color: Color(0xFFEF4444)),
                const SizedBox(height: 20),
                const Text('위치 권한이 필요해요',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                const SizedBox(height: 10),
                const Text('캠퍼스런치는 위치 권한 없이\n이용할 수 없어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6)),
                const Spacer(),
                _btn('설정에서 권한 허용하기', const Color(0xFF111827), Colors.white, _loading ? null : _openSettings),
                const SizedBox(height: 10),
                _btn('다시 시도', const Color(0xFF9ECA8B), const Color(0xFF111827), _loading ? null : _confirm),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '환영합니다!\n서비스 이용을 위해\n아래 약관에 동의해 주세요.',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        height: 1.25,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // 전체동의
                    _AllAgreeRow(
                      checked: _allChecked,
                      onTap: () => _toggleAll(!_allChecked),
                    ),
                    const Divider(height: 28, color: Color(0xFFE5E7EB)),

                    // 개별 항목
                    _ConsentRow(
                      checked: _location,
                      label: '위치 기반 서비스 이용 동의',
                      required: true,
                      onTap: () => setState(() => _location = !_location),
                    ),
                    const SizedBox(height: 4),
                    _ConsentRow(
                      checked: _nearby,
                      label: '주변 기기 탐색 동의',
                      required: true,
                      onTap: () => setState(() => _nearby = !_nearby),
                    ),
                    const SizedBox(height: 4),
                    _ConsentRow(
                      checked: _marketing,
                      label: '마케팅 정보 앱 푸시 알림 수신 동의',
                      required: false,
                      subText: '이벤트 및 혜택 정보를 받아보실 수 있어요.',
                      onTap: () => setState(() => _marketing = !_marketing),
                    ),
                  ],
                ),
              ),
            ),

            // 시작하기 버튼
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: GestureDetector(
                onTap: _allRequired && !_loading ? _confirm : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _allRequired ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)),
                          )
                        : Text(
                            '시작하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _allRequired ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg))),
        ),
      );
}

class _AllAgreeRow extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const _AllAgreeRow({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          _Checkbox(checked: checked),
          const SizedBox(width: 12),
          const Text('전체동의',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool checked;
  final String label;
  final bool required;
  final String? subText;
  final VoidCallback onTap;

  const _ConsentRow({
    required this.checked,
    required this.label,
    required this.required,
    required this.onTap,
    this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Checkbox(checked: checked),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      children: [
                        TextSpan(text: label),
                        TextSpan(
                          text: required ? ' (필수)' : ' (선택)',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: required ? const Color(0xFF5E8C4A) : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (subText != null) ...[
                    const SizedBox(height: 2),
                    Text(subText!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool checked;
  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF9ECA8B) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? const Color(0xFF9ECA8B) : const Color(0xFFD1D5DB),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Color(0xFF111827))
          : null,
    );
  }
}
