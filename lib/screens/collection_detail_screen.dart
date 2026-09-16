import 'package:flutter/material.dart';

import '../models/collection.dart';
import '../models/restaurant.dart';
import '../widgets/collection_detail_restaurant_row.dart';
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
    matched.sort((a, b) => a.$1.sortOrder.compareTo(b.$1.sortOrder));

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
                final (item, restaurant) = matched[i];
                return CollectionDetailRestaurantRow(
                  restaurant: restaurant,
                  note: item.note,
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
