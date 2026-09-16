import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/restaurant.dart';
import 'restaurant_image.dart';
import 'rice_ball_icon.dart';

/// 맛집컬렉션 세부페이지(전체 매장 목록) 전용 카드.
/// 홈의 CollectionRestaurantCard(세로형, 이미지 위 텍스트 오버레이)와 달리
/// 가로로 넓은 리스트 행 형태이며, 컬렉션에 달린 매장별 한줄소개(note)를
/// 키컬러·전용 폰트로 강조해서 보여준다. 상태뱃지는 표시하지 않는다.
/// 모든 매장이 완전히 동일한 카드 높이·이미지 크기를 갖도록 고정 높이를 쓴다.
class CollectionDetailRestaurantRow extends StatelessWidget {
  static const double _rowHeight = 108;

  final Restaurant restaurant;
  final String? note;
  final VoidCallback onTap;

  const CollectionDetailRestaurantRow({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final trimmedNote = note?.trim() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: SizedBox(
                width: _rowHeight,
                height: _rowHeight,
                child: RestaurantImage(
                  url: r.imageUrl,
                  fallback: () => const _IconBox(),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF000000),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      r.area == r.category ? r.area : '${r.area} · ${r.category}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trimmedNote.isNotEmpty ? '“$trimmedNote”' : '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryCta,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const RiceBallIcon(size: 40),
    );
  }
}
