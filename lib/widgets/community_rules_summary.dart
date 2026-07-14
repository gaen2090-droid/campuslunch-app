import 'package:flutter/material.dart';

import '../constants/community_rules.dart';
import '../screens/legal_document_screen.dart';

/// 커뮤니티 이용규칙 요약 — 소분류 제목만 표시, 상세는 전체보기
class CommunityRulesSummary extends StatelessWidget {
  const CommunityRulesSummary({
    super.key,
    this.showViewAllButton = true,
  });

  final bool showViewAllButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showViewAllButton) ...[
          Center(
            child: TextButton(
              onPressed: () => _openFullPolicy(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CommunityRules.viewAllLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < CommunityRules.summarySections.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Text(
            CommunityRules.summarySections[i].heading,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  static void openFullPolicy(BuildContext context) => _openFullPolicy(context);

  static Future<void> _openFullPolicy(BuildContext context) {
    return LegalDocumentScreen.open(
      context,
      title: CommunityRules.policyTitle,
      assetPath: CommunityRules.policyAssetPath,
    );
  }
}
