import 'package:flutter/material.dart';

import '../constants/legal_terms.dart';
import 'legal_document_screen.dart';

/// 마이페이지 > 약관 및 정책 — 문서 목록
class LegalPolicyHubScreen extends StatelessWidget {
  const LegalPolicyHubScreen({super.key});

  static const _extra = [
    LegalTermsCheckItem(
      id: 'location',
      label: '위치기반서비스 이용약관',
      required: false,
      assetPath: 'assets/legal/LOCATION_TERMS.md',
    ),
    LegalTermsCheckItem(
      id: 'community',
      label: '커뮤니티 이용정책',
      required: false,
      assetPath: 'assets/legal/COMMUNITY_POLICY.md',
    ),
    LegalTermsCheckItem(
      id: 'business_info',
      label: '사업자 정보',
      required: false,
      assetPath: 'assets/legal/BUSINESS_INFO.md',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      ...LegalTerms.checkItems.where((item) => item.assetPath != null),
      ..._extra,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '약관 및 정책',
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
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => LegalDocumentScreen.open(
                context,
                title: item.label,
                assetPath: item.assetPath!,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
