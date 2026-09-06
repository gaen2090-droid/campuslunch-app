import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../models/community_inbox_notification.dart';

/// 정지/해제 이후 첫 로그인 시 홈 화면에 뜨는 안내 팝업.
/// 알림창의 정지 알림과 같은 문구(헤드라인+사유)를 쓰되, 뒷배경을 어둡게 깔고
/// 화면 중앙에 카드로 띄운다.
class SuspensionPopupDialog {
  static Future<void> checkAndShow(BuildContext context) async {
    final repo = context.read<AppProvider>().community;
    CommunityInboxNotification? notice;
    try {
      notice = await repo.fetchPendingSuspensionPopup();
    } catch (_) {
      return;
    }
    if (notice == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuspensionPopupContent(notice: notice!),
    );
    try {
      await repo.markSuspensionPopupSeen(notice.eventId);
    } catch (_) {}
  }
}

class _SuspensionPopupContent extends StatelessWidget {
  final CommunityInboxNotification notice;

  const _SuspensionPopupContent({required this.notice});

  @override
  Widget build(BuildContext context) {
    final reasonText = notice.adminReasonText;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notice.adminHeadline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF000000),
                height: 1.4,
              ),
            ),
            if (reasonText != null) ...[
              const SizedBox(height: 10),
              Text(
                reasonText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              '마이페이지 계정 설정 > 이용 제한 내역에서 확인 가능',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF000000),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
