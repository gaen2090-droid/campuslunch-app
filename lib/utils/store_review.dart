import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// iOS StoreKit / Android Play In-App Review 시스템 시트만 요청.
/// 커스텀 다이얼로그 없음. 표시·「안 함」여부는 OS가 결정하며 앱에서 알 수 없음.
Future<void> requestNativeStoreReview() async {
  if (kIsWeb) return;
  try {
    final review = InAppReview.instance;
    if (!await review.isAvailable()) {
      debugPrint('[StoreReview] in-app review unavailable');
      return;
    }
    await review.requestReview();
  } catch (e) {
    debugPrint('[StoreReview] requestReview failed: $e');
  }
}
