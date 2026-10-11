import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/restaurant.dart';
import 'restaurant_image.dart';
import 'rice_ball_icon.dart';

/// 맛집컬렉션 세부페이지(전체 매장 목록) 전용 카드.
/// 홈의 CollectionRestaurantCard(세로형, 이미지 위 텍스트 오버레이)와 달리
/// 가로로 넓은 리스트 행 형태이며, 컬렉션에 달린 매장별 한줄소개(note)를
/// 키컬러·전용 폰트로 강조해서 보여준다. 상태뱃지는 표시하지 않는다.
/// 카드 높이는 한줄소개가 1줄이면 1줄에, 2줄이면 2줄에 맞춰진다(최소 _rowHeight).
/// 이미지는 가로 _imageWidth 고정, 세로는 카드 높이에 맞춰 채운다.
class CollectionDetailRestaurantRow extends StatelessWidget {
  // 카드 높이는 내용(한줄소개 1줄/2줄)에 맞춰 달라진다. 이건 최소 높이일 뿐이다.
  static const double _rowHeight = 80;
  static const double _imageWidth = 96;

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
        constraints: const BoxConstraints(minHeight: _rowHeight),
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
        // 이미지는 Positioned로 깔아서 카드 높이에 영향을 주지 않는다.
        // (IntrinsicHeight + Row로 하면 세로로 긴 이미지가 카드 높이를 키운다.)
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _imageWidth,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: RestaurantImage(
                  url: r.imageUrl,
                  fallback: () => const _IconBox(),
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: _rowHeight - 2),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(_imageWidth + 14, 10, 14, 10),
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
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    r.area == r.category ? r.area : '${r.area} · ${r.category}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF), height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 13),
                  Text(
                    trimmedNote.isNotEmpty ? '“$trimmedNote”' : '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryCta,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
