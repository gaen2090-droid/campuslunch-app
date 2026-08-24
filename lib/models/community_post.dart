class CommunityPost {
  final String id;

  /// 작성자 user id. 차단 기능에서 사용.
  /// community_my_posts 등 아직 author_id를 반환하지 않는 RPC 경로에서는 null.
  final String? authorId;
  final String content;
  final List<String> imageUrls;
  final String nickname;
  final String? restaurantId;
  final String? restaurantName;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isOwner;
  final bool isAuthorOwner;
  final bool isAuthorAdmin;
  final bool isPinned;
  final bool hasPoll;
  final int pollVoterCount;

  const CommunityPost({
    required this.id,
    this.authorId,
    required this.content,
    required this.imageUrls,
    required this.nickname,
    this.restaurantId,
    this.restaurantName,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
    this.updatedAt,
    required this.isOwner,
    this.isAuthorOwner = false,
    this.isAuthorAdmin = false,
    this.isPinned = false,
    this.hasPoll = false,
    this.pollVoterCount = 0,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    return CommunityPost(
      id: map['id'] as String,
      authorId: map['author_id'] as String?,
      content: map['content'] as String,
      imageUrls: (map['image_urls'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      nickname: map['nickname'] as String? ?? '탈퇴한 사용자',
      restaurantId: map['restaurant_id'] as String?,
      restaurantName: map['restaurant_name'] as String?,
      likeCount: map['like_count'] as int? ?? 0,
      commentCount: map['comment_count'] as int? ?? 0,
      likedByMe: map['liked_by_me'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      isOwner: map['is_owner'] as bool? ?? false,
      isAuthorOwner: map['is_author_owner'] as bool? ?? false,
      isAuthorAdmin: map['is_author_admin'] as bool? ?? false,
      isPinned: map['is_pinned'] as bool? ?? false,
      hasPoll: map['has_poll'] as bool? ?? false,
      pollVoterCount: map['poll_voter_count'] as int? ?? 0,
    );
  }

  CommunityPost copyWith({
    int? likeCount,
    bool? likedByMe,
  }) {
    return CommunityPost(
      id: id,
      authorId: authorId,
      content: content,
      imageUrls: imageUrls,
      nickname: nickname,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isOwner: isOwner,
      isAuthorOwner: isAuthorOwner,
      isAuthorAdmin: isAuthorAdmin,
      isPinned: isPinned,
      hasPoll: hasPoll,
      pollVoterCount: pollVoterCount,
    );
  }
}
