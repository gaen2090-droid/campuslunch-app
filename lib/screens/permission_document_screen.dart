import 'package:flutter/material.dart';

/// 권한 동의 항목의 약관 전문 화면
class PermissionDocumentScreen extends StatelessWidget {
  const PermissionDocumentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PermissionDocumentScreen(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
            height: 1.7,
          ),
        ),
      ),
    );
  }
}
