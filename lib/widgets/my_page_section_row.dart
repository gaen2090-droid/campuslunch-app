import 'package:flutter/material.dart';

/// 마이페이지 섹션 안의 아이콘 + 라벨 + 화살표 리스트 행 (settings_screen의
/// _SettingsButton과 동일한 시각 스타일을 공용화).
class MyPageSectionRow extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showBottomBorder;

  const MyPageSectionRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.showBottomBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: showBottomBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
              : null,
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}

/// 섹션 제목 (예: "쿠폰/이벤트", "비즈니스", "고객지원")
class MyPageSectionTitle extends StatelessWidget {
  final String text;
  const MyPageSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

/// 섹션 사이를 나누는 회색 막대 (끝이 둥근 카드 대신 사용).
class MyPageSectionDivider extends StatelessWidget {
  const MyPageSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      color: const Color(0xFFF3F4F6),
    );
  }
}
