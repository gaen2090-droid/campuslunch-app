import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

/// 권한 동의 항목의 약관 전문 화면
class PermissionDocumentScreen extends StatelessWidget {
  const PermissionDocumentScreen({
    super.key,
    required this.title,
    required this.body,
    this.fullDocumentAssetPath,
    this.fullDocumentLinkLabel,
  });

  final String title;
  final String body;

  /// 별도 정식 약관 전문이 있는 경우 해당 에셋 경로.
  final String? fullDocumentAssetPath;
  final String? fullDocumentLinkLabel;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required String body,
    String? fullDocumentAssetPath,
    String? fullDocumentLinkLabel,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PermissionDocumentScreen(
          title: title,
          body: body,
          fullDocumentAssetPath: fullDocumentAssetPath,
          fullDocumentLinkLabel: fullDocumentLinkLabel,
        ),
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
              size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                height: 1.7,
              ),
            ),
            if (fullDocumentAssetPath != null) ...[
              const SizedBox(height: 20),
              InkWell(
                onTap: () => LegalDocumentScreen.open(
                  context,
                  title: title,
                  assetPath: fullDocumentAssetPath!,
                ),
                child: Text(
                  fullDocumentLinkLabel ?? '전문 보기',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF000000),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
