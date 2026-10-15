import 'package:flutter/material.dart';

/// 홈 상단: 점메추 요정과 점심 룰렛을 한 줄에 나란히 놓는 타일.
/// 마이 탭용 가로 배너([LunchFairyBanner], [LunchRouletteBanner])와 별개로 두었다.
class LunchHomeTiles extends StatelessWidget {
  final VoidCallback onFairyTap;
  final VoidCallback onRouletteTap;

  const LunchHomeTiles({
    super.key,
    required this.onFairyTap,
    required this.onRouletteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Tile(
                color: const Color(0xFFE6F3EC),
                icon: Image.asset('assets/images/fairy.png',
                    width: 40, height: 40),
                title: '점메추 요정',
                subtitle: '3초만에 메뉴 추천',
                onTap: onFairyTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                color: const Color(0xFFFFF4CC),
                icon: Image.asset('assets/images/roulette.png',
                    width: 40, height: 40),
                title: '식당 룰렛',
                subtitle: '고민될땐 룰렛 돌리기',
                onTap: onRouletteTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Color color;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'OkDanDan',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
