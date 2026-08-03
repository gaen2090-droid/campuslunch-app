import 'package:flutter/material.dart';

import '../utils/recent_history_store.dart';

/// 최근 목록(검색어/매장 열람) 리스트 행 — 홈/지도 검색 화면 공용.
/// 검색어는 왼쪽에 돋보기 아이콘, 매장은 매장(storefront) 아이콘.
class RecentHistoryRow extends StatelessWidget {
  final RecentHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const RecentHistoryRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isSearch = entry.type == RecentHistoryType.search;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch ? Icons.search : Icons.storefront_rounded,
                size: 16,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${entry.timestamp.month.toString().padLeft(2, '0')}.${entry.timestamp.day.toString().padLeft(2, '0')}.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
