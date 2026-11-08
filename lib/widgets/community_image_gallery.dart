import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'full_screen_image_viewer.dart';

/// 게시글 상세의 사진 영역. 정사각형 썸네일이 가로로 이어지며(오른쪽 화면 끝까지
/// 스크롤), 누르면 전체 화면 뷰어([FullScreenImageViewer])가 열린다.
class CommunityImageGallery extends StatelessWidget {
  final List<String> urls;

  /// 이 위젯을 감싼 부모의 좌우 여백. 스트립이 오른쪽 화면 끝까지 이어지도록
  /// 오른쪽 여백만큼 영역을 넓힌다.
  final double sidePadding;

  static const _gap = 10.0;
  static const _radius = 16.0;

  const CommunityImageGallery({
    super.key,
    required this.urls,
    this.sidePadding = 20,
  });

  Future<void> _open(BuildContext context, int index) {
    return FullScreenImageViewer.show(context, urls: urls, initialIndex: index);
  }

  Widget _thumb(BuildContext context, int i, double size, {double? width}) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      onTap: () => _open(context, i),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: SizedBox(
          width: width ?? size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            // 썸네일은 작게 디코딩해 메모리를 아낀다.
            memCacheWidth: ((width ?? size) * dpr).round(),
            placeholder: (_, __) => Container(color: const Color(0xFFF3F4F6)),
            errorWidget: (_, __, ___) => Container(
              color: const Color(0xFFF3F4F6),
              child: const Icon(Icons.broken_image_outlined,
                  color: Color(0xFF9CA3AF)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth - sidePadding * 2;

    // 1장이면 본문 폭에 맞춰 크게 보여준다.
    if (urls.length == 1) {
      return _thumb(context, 0, 260, width: contentWidth);
    }

    // 2장 이상: 화면 폭의 약 36% 정사각형 썸네일이 이어진다.
    final size = screenWidth * 0.36;
    return SizedBox(
      height: size,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: contentWidth + sidePadding,
        maxWidth: contentWidth + sidePadding,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(right: sidePadding),
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: _gap),
          itemBuilder: (context, i) => _thumb(context, i, size),
        ),
      ),
    );
  }
}
