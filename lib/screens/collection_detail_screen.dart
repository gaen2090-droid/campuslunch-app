import 'package:flutter/material.dart';

import '../models/collection.dart';
import '../models/restaurant.dart';
import '../widgets/restaurant_card.dart';
import 'detail_screen.dart';

class CollectionDetailScreen extends StatelessWidget {
  final RestaurantCollection collection;
  final List<CollectionItem> items;
  final List<Restaurant> restaurants;

  const CollectionDetailScreen({
    super.key,
    required this.collection,
    required this.items,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    final matched = <(CollectionItem, Restaurant)>[];
    for (final item in items) {
      Restaurant? r;
      for (final candidate in restaurants) {
        if (candidate.id == item.restaurantId) {
          r = candidate;
          break;
        }
      }
      if (r != null) matched.add((item, r));
    }
    int groupOf(Restaurant r) {
      if (r.status == '영업안함') return 2;
      if (!r.hasCrowdUpdate) return 1;
      return 0;
    }
    matched.sort((a, b) {
      final groupDiff = groupOf(a.$2).compareTo(groupOf(b.$2));
      if (groupDiff != 0) return groupDiff;
      final aTime = a.$2.updatedAt;
      final bTime = b.$2.updatedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          collection.title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: matched.isEmpty
          ? const Center(
              child: Text('담긴 매장이 없어요.', style: TextStyle(color: Color(0xFF9CA3AF))),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: matched.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final (_, restaurant) = matched[i];
                return RestaurantCard(
                  restaurant: restaurant,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailScreen(restaurant: restaurant)),
                  ),
                );
              },
            ),
    );
  }
}
