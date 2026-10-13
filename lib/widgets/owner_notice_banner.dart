import 'package:flutter/material.dart';

/// 관리자가 사장님에게 보내는 공지. 커뮤니티 공지 박스(community_screen)와 같은 톤이되,
/// 사장님은 내용을 끝까지 읽어야 하므로 줄바꿈을 허용한다(최대 300자).
class OwnerNoticeBanner extends StatelessWidget {
  final String content;
  const OwnerNoticeBanner({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text(
              '공지',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
