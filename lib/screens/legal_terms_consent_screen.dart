import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/legal_terms.dart';
import '../providers/app_provider.dart';
import '../widgets/consent_checklist.dart';
import '../widgets/rice_ball_icon.dart';
import 'legal_document_screen.dart';

/// 회원가입 직후 — 약관·정책 동의
class LegalTermsConsentScreen extends StatefulWidget {
  const LegalTermsConsentScreen({super.key});

  @override
  State<LegalTermsConsentScreen> createState() =>
      _LegalTermsConsentScreenState();
}

class _LegalTermsConsentScreenState extends State<LegalTermsConsentScreen> {
  bool _loading = false;
  late Map<String, bool> _agreed;

  @override
  void initState() {
    super.initState();
    _agreed = {
      for (final item in LegalTerms.checkItems) item.id: false,
    };
  }

  List<ConsentCheckItem> get _checkItems => LegalTerms.checkItems
      .map(
        (item) => ConsentCheckItem(
          id: item.id,
          label: item.label,
          required: item.required,
        ),
      )
      .toList();

  bool get _canProceed => isRequiredLegalTermsGranted(_agreed);

  void _openDocument(String id) {
    final item = LegalTerms.itemById(id);
    if (item == null) return;
    LegalDocumentScreen.open(
      context,
      title: item.label,
      assetPath: item.assetPath,
    );
  }

  Future<void> _confirm() async {
    if (_loading || !_canProceed) return;
    setState(() => _loading = true);
    await context.read<AppProvider>().completeLegalTermsConsent();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _canProceed && !_loading;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F0),
      body: Stack(
        children: [
          Positioned(
            left: -100,
            bottom: 80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 60,
                sigmaY: 60,
                tileMode: TileMode.decal,
              ),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF9ECA8B).withAlpha(180),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9ECA8B),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Center(
                              child: RiceBallIcon(size: 30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          LegalTerms.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          LegalTerms.intro,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '문의: ${LegalTerms.contactEmail}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ConsentChecklist(
                          agreeAllLabel: LegalTerms.agreeAllLabel,
                          items: _checkItems,
                          agreed: _agreed,
                          onChanged: (next) => setState(() => _agreed = next),
                          onViewDocument: _openDocument,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            '각 항목의 「전문 보기」에서 약관·정책 전문을 '
                            '확인할 수 있습니다. 필수 항목에 동의하지 않으면 '
                            '서비스를 이용할 수 없습니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        _canProceed
                            ? '동의 후 캠퍼스런치를 시작합니다.'
                            : '필수 약관·정책에 모두 동의해야 합니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: _canProceed
                              ? const Color(0xFF6B7280)
                              : const Color(0xFFEF4444),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: canProceed ? _confirm : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: canProceed
                                ? const Color(0xFF9ECA8B)
                                : const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: canProceed
                                ? const [
                                    BoxShadow(
                                      color: Color(0xFFC8E6BA),
                                      blurRadius: 20,
                                      offset: Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF111827),
                                    ),
                                  )
                                : Text(
                                    LegalTerms.confirmLabel,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: canProceed
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
