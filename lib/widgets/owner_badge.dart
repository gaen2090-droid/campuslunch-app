import 'package:flutter/material.dart';

/// 커뮤니티 글/댓글 작성자가 매장 사장님(오너)일 때 표시하는 배지.
class OwnerBadge extends StatelessWidget {
  const OwnerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '사장님',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}
