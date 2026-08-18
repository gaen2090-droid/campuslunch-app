import 'package:flutter/material.dart';

/// 사용자 차단 전 확인 다이얼로그.
/// 차단하면 상대의 글·댓글이 즉시 보이지 않고 운영자에게 신고가 접수된다는
/// 점을 안내한다 (App Store 가이드라인 1.2).
Future<bool> confirmBlockUser(BuildContext context, String nickname) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('사용자 차단', style: TextStyle(fontWeight: FontWeight.w900)),
      content: Text(
        '$nickname님을 차단할까요?\n\n'
        '차단하면 이 사용자의 게시글과 댓글이 바로 보이지 않고, '
        '운영자에게 신고가 함께 접수돼요. '
        '차단은 커뮤니티 메뉴 → 차단 관리에서 해제할 수 있어요.',
        style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소', style: TextStyle(color: Color(0xFF9CA3AF))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            '차단',
            style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
