import 'package:flutter/material.dart';
import '../models/restaurant.dart';

class ReportSheet extends StatelessWidget {
  final Restaurant restaurant;
  final ValueChanged<String> onSubmit;

  const ReportSheet({
    super.key,
    required this.restaurant,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context,
    Restaurant restaurant,
    ValueChanged<String> onSubmit,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x59000000),
      builder: (_) => ReportSheet(restaurant: restaurant, onSubmit: onSubmit),
    );
  }

  @override
  Widget build(BuildContext context) {
    const options = reportOptions;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '지금 매장 상황이 어떤가요?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            restaurant.name,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          ...options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onSubmit(o.status);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: o.bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: o.borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(o.icon, size: 24, color: o.textColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                o.label,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: o.textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                o.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  '닫기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 혼잡도 제보 옵션 — 유저 제보 시트와 사장님 탭이 공유하는 단일 진실 소스.
/// 둘 중 한쪽만 고치면 어긋나므로, 라벨/색상을 바꿀 땐 여기만 수정한다.
class ReportOption {
  final String label;
  final String subtitle;
  final String status;
  final IconData icon;
  final Color borderColor;
  final Color bgColor;
  final Color textColor;

  const ReportOption({
    required this.label,
    required this.subtitle,
    required this.status,
    required this.icon,
    required this.borderColor,
    required this.bgColor,
    required this.textColor,
  });
}

const reportOptions = [
  ReportOption(
    label: '여유로워요',
    subtitle: '바로 앉을 수 있어요',
    status: '여유로움',
    icon: Icons.sentiment_satisfied_alt,
    borderColor: Color(0xFFCDE9DC),
    bgColor: Color(0xFFEDF7F2),
    textColor: Color(0xFF26BC7D),
  ),
  ReportOption(
    label: '약간 혼잡해요',
    subtitle: '빈자리 조금 있어요',
    status: '약간혼잡',
    icon: Icons.sentiment_neutral,
    borderColor: Color(0xFFFDE68A),
    bgColor: Color(0xFFFFFBEB),
    textColor: Color(0xFFF59E0B),
  ),
  ReportOption(
    label: '자리가 없어요',
    subtitle: '기다려야 해요',
    status: '자리없음',
    icon: Icons.groups,
    borderColor: Color(0xFFFECACA),
    bgColor: Color(0xFFFEF2F2),
    textColor: Color(0xFFEF4444),
  ),
];
