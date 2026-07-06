class CommunityComment {
  final String id;
  final String content;
  final String nickname;
  final DateTime createdAt;
  final bool isOwner;

  const CommunityComment({
    required this.id,
    required this.content,
    required this.nickname,
    required this.createdAt,
    required this.isOwner,
  });

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    return CommunityComment(
      id: map['id'] as String,
      content: map['content'] as String,
      nickname: map['nickname'] as String? ?? '탈퇴한 사용자',
      createdAt: DateTime.parse(map['created_at'] as String),
      isOwner: map['is_owner'] as bool? ?? false,
    );
  }
}
