class CommunityCommentNotification {
  final String commentId;
  final String postId;
  final String postContent;
  final String commenterNickname;
  final String commentContent;
  final DateTime createdAt;

  const CommunityCommentNotification({
    required this.commentId,
    required this.postId,
    required this.postContent,
    required this.commenterNickname,
    required this.commentContent,
    required this.createdAt,
  });

  factory CommunityCommentNotification.fromMap(Map<String, dynamic> map) {
    return CommunityCommentNotification(
      commentId: map['comment_id'] as String,
      postId: map['post_id'] as String,
      postContent: map['post_content'] as String,
      commenterNickname: map['commenter_nickname'] as String? ?? '탈퇴한 사용자',
      commentContent: map['comment_content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
