import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/reward_limits.dart';
import '../providers/app_provider.dart';

Future<void> submitCrowdReportFeedback(
  BuildContext context,
  String restaurantId,
  String status,
) async {
  final provider = context.read<AppProvider>();
  final err = await provider.reportStatus(restaurantId, status);
  if (!context.mounted) return;

  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        duration: const Duration(milliseconds: 2200),
        elevation: 0,
      ),
    );
    return;
  }

  final stamp = provider.lastStampResult;
  String message;
  if (!stamp.granted && stamp.todayStamps == 0 && stamp.totalStamps == 0) {
    // 사장님 제보 또는 Supabase 미연결
    message = '소중한 제보 감사드려요!';
  } else if (stamp.granted) {
    message =
        '혼잡도 제보가 등록되었어요.\n스탬프가 적립되었어요! (오늘 ${stamp.todayStamps}/${RewardLimits.dailyStampCap})';
  } else if (stamp.totalStamps >= RewardLimits.stampsPerGifticon) {
    message =
        '혼잡도 제보가 등록되었어요.\n스탬프 ${RewardLimits.stampsPerGifticon}개를 모았어요. 기프티콘 재고 확인 중이에요.';
  } else {
    message = '혼잡도 제보가 등록되었어요.\n오늘 스탬프를 모두 받았어요. 내일 다시 받을 수 있어요.';
  }

  final autoRedeemSucceeded = stamp.autoRedeem.succeeded;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      backgroundColor: const Color(0xFF9ECA8B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: Duration(milliseconds: autoRedeemSucceeded ? 1600 : 2800),
      elevation: 0,
    ),
  );

  if (!autoRedeemSucceeded) return;

  await Future.delayed(const Duration(milliseconds: 1600));
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '커피 쿠폰이 발급됐어요. 확인해보세요!\n(마이페이지 > 내 스탬프 > 쿠폰함)',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      backgroundColor: const Color(0xFF9ECA8B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(milliseconds: 2800),
      elevation: 0,
    ),
  );
}
