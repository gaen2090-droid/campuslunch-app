class CommunityComment {
  final String id;
  final String content;
  final String nickname;
  final DateTime createdAt;
  final bool isOwner;
  final bool isAuthorOwner;
  final int likeCount;
  final bool likedByMe;
  final String? parentCommentId;

  const CommunityComment({
    required this.id,
    required this.content,
    required this.nickname,
    required this.createdAt,
    required this.isOwner,
    this.isAuthorOwner = false,
    this.likeCount = 0,
    this.likedByMe = false,
    this.parentCommentId,
  });

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    return CommunityComment(
      id: map['id'] as String,
      content: map['content'] as String,
      nickname: map['nickname'] as String? ?? '탈퇴한 사용자',
      createdAt: DateTime.parse(map['created_at'] as String),
      isOwner: map['is_owner'] as bool? ?? false,
      isAuthorOwner: map['is_author_owner'] as bool? ?? false,
      likeCount: map['like_count'] as int? ?? 0,
      likedByMe: map['liked_by_me'] as bool? ?? false,
      parentCommentId: map['parent_comment_id'] as String?,
    );
  }

  CommunityComment copyWith({
    int? likeCount,
    bool? likedByMe,
  }) {
    return CommunityComment(
      id: id,
      content: content,
      nickname: nickname,
      createdAt: createdAt,
      isOwner: isOwner,
      isAuthorOwner: isAuthorOwner,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      parentCommentId: parentCommentId,
    );
  }
}
