import 'package:flutter/material.dart';

import '../models/collection.dart';
import '../models/restaurant.dart';
import 'collection_restaurant_card.dart';

/// 컬렉션 1개: 헤더(제목+매장수, 부제) + 가로 스크롤 매장 카드 리스트
class CollectionSection extends StatelessWidget {
  final RestaurantCollection collection;
  final List<CollectionItem> items;
  final List<Restaurant> restaurants;
  final void Function(Restaurant) onTapRestaurant;
  final void Function(RestaurantCollection, List<CollectionItem>) onSeeAll;
  final void Function(RestaurantCollection) onTapComments;
  final VoidCallback onTapLike;

  const CollectionSection({
    super.key,
    required this.collection,
    required this.items,
    required this.restaurants,
    required this.onTapRestaurant,
    required this.onSeeAll,
    required this.onTapComments,
    required this.onTapLike,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    for (final item in items) {
      Restaurant? r;
      for (final candidate in restaurants) {
        if (candidate.id == item.restaurantId) {
          r = candidate;
          break;
        }
      }
      if (r == null) continue;
      cards.add(Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 160,
          child: CollectionRestaurantCard(
            restaurant: r,
            note: item.note,
            onTap: () => onTapRestaurant(r!),
          ),
        ),
      ));
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (collection.subtitle != null && collection.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          collection.subtitle!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onSeeAll(collection, items),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.chevron_right, size: 32, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: cards,
            ),
          ),
          if (collection.hashtags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in collection.hashtags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onTapLike,
                  child: Row(
                    children: [
                      Icon(
                        collection.likedByMe ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: collection.likedByMe ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${collection.likeCount}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => onTapComments(collection),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 20, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text(
                        '${collection.commentCount}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
