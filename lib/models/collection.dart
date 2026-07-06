class RestaurantCollection {
  final String id;
  final String title;
  final String? subtitle;
  final int sortOrder;
  final int likeCount;
  final bool likedByMe;
  final int commentCount;

  const RestaurantCollection({
    required this.id,
    required this.title,
    this.subtitle,
    required this.sortOrder,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
  });

  factory RestaurantCollection.fromMap(Map<String, dynamic> map) {
    return RestaurantCollection(
      id: map['id'] as String,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      likeCount: map['like_count'] as int? ?? 0,
      likedByMe: map['liked_by_me'] as bool? ?? false,
      commentCount: map['comment_count'] as int? ?? 0,
    );
  }

  RestaurantCollection copyWith({int? likeCount, bool? likedByMe, int? commentCount}) {
    return RestaurantCollection(
      id: id,
      title: title,
      subtitle: subtitle,
      sortOrder: sortOrder,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}

class CollectionItem {
  final String id;
  final String restaurantId;
  final String? note;
  final int sortOrder;

  const CollectionItem({
    required this.id,
    required this.restaurantId,
    this.note,
    required this.sortOrder,
  });

  factory CollectionItem.fromMap(Map<String, dynamic> map) {
    return CollectionItem(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      note: map['note'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}
