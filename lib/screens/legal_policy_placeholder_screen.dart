import 'package:flutter/material.dart';

/// 약관 및 정책 — 콘텐츠 준비 전 placeholder.
class LegalPolicyPlaceholderScreen extends StatelessWidget {
  const LegalPolicyPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '약관 및 정책',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: false,
      ),
      body: const Center(
        child: Text(
          '준비 중이에요.',
          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}
