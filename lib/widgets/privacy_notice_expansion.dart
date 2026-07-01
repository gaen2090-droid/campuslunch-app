import 'package:flutter/material.dart';
import '../constants/privacy_notice.dart';

/// 로그인 등에서 접고 펼 수 있는 개인정보 수집·이용 안내
class PrivacyNoticeExpansion extends StatefulWidget {
  const PrivacyNoticeExpansion({super.key});

  @override
  State<PrivacyNoticeExpansion> createState() => _PrivacyNoticeExpansionState();
}

class _PrivacyNoticeExpansionState extends State<PrivacyNoticeExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    size: 18,
                    color: Color(0xFF5E8C4A),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      PrivacyNotice.collectionTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: PrivacyNoticeBody(compact: true),
            ),
          ],
        ],
      ),
    );
  }
}

class PrivacyNoticeBody extends StatelessWidget {
  const PrivacyNoticeBody({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PrivacyNotice.collectionIntro,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: const Color(0xFF6B7280),
            height: 1.55,
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        ...PrivacyNotice.collectionItems.map(
          (item) => _CollectionBlock(item: item, compact: compact),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          PrivacyNotice.rightsNotice,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            color: const Color(0xFF9CA3AF),
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _CollectionBlock extends StatelessWidget {
  const _CollectionBlock({required this.item, required this.compact});

  final PrivacyCollectionItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: compact ? 11 : 12,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF374151),
    );
    final valueStyle = TextStyle(
      fontSize: compact ? 11 : 12,
      color: const Color(0xFF6B7280),
      height: 1.5,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.category, style: labelStyle),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.required
                      ? const Color(0xFFDAFFCA)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.required ? '필수' : '선택',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: item.required
                        ? const Color(0xFF4C9C2A)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('항목: ${item.items}', style: valueStyle),
          Text('목적: ${item.purpose}', style: valueStyle),
          Text('보관: ${item.retention}', style: valueStyle),
        ],
      ),
    );
  }
}
