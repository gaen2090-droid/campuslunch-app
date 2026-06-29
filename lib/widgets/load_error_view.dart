import 'package:flutter/material.dart';

/// 네트워크/서버 로드 실패 시 공통 안내 + 재시도 버튼
class LoadErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  final EdgeInsetsGeometry padding;

  const LoadErrorView({
    super.key,
    required this.onRetry,
    this.message = '네트워크 연결을 확인해주세요.',
    this.padding = const EdgeInsets.fromLTRB(20, 48, 20, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 28, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
