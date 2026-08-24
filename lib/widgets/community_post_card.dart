import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../utils/time_ago.dart';
import 'admin_badge.dart';
import 'owner_badge.dart';

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
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
                      Text(
                        post.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
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
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: const Color(0xFFF3F4F6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (post.restaurantId != null && post.restaurantName != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onRestaurantTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F3EC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 14, color: Color(0xFF26BC7D)),
                      const SizedBox(width: 4),
                      Text(
                        post.restaurantName!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF26BC7D)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                        '${post.likeCount}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
                if (post.hasPoll) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.poll_outlined, size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    '${post.pollVoterCount}명',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
