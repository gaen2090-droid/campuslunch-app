import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../utils/time_ago.dart';
import 'admin_badge.dart';
import 'owner_badge.dart';

String _countLabel(int count) => count > 999 ? '999+' : '$count';

class CommunityPostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onRestaurantTap;

  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    this.onRestaurantTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.nickname,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
                            ),
                          ),
                          if (post.isAuthorOwner) ...[
                            const SizedBox(width: 4),
                            const OwnerBadge(),
                          ],
                          if (post.isAuthorAdmin) ...[
                            const SizedBox(width: 4),
                            const AdminBadge(),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            timeAgo(post.createdAt),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                          if (post.updatedAt != null) ...[
                            const SizedBox(width: 4),
                            const Text('· 수정됨', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final hasBadge =
                            post.restaurantId != null && post.restaurantName != null;
                        // 매장 뱃지가 있으면 본문을 1줄로 줄여 "본문 1줄 + 뱃지"
                        // 블록 높이가 뱃지 없는 카드의 "본문 2줄" 블록 높이와
                        // 비슷해지도록 한다. 뱃지 없는 카드는 그대로 2줄까지 자연
                        // 높이를 쓰고, 짧은 글은 짧은 대로 더 작게 남는다.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.content,
                              maxLines: hasBadge ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
                            ),
                            if (hasBadge) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: onRestaurantTap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F3EC),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.storefront_outlined, size: 11, color: Color(0xFF26BC7D)),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          post.restaurantName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                            color: Color(0xFF26BC7D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                              post.likedByMe ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: post.likedByMe ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _countLabel(post.likeCount),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text(
                        _countLabel(post.commentCount),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                      if (post.hasPoll) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.poll_outlined, size: 16, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          '${_countLabel(post.pollVoterCount)}명',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrls.first,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 92,
                    height: 92,
                    color: const Color(0xFFF3F4F6),
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
