import 'package:flutter/material.dart';

/// 커뮤니티 글/댓글 작성자가 관리자(admin)일 때 표시하는 배지.
class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '관리자',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}
