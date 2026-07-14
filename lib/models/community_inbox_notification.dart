/// 커뮤니티 인박스 (댓글 + 좋아요)
enum CommunityInboxKind { comment, like }

class CommunityInboxNotification {
  final CommunityInboxKind kind;
  final String eventId;
  final String postId;
  final String postContent;
  final String actorNickname;
  final String bodyText;
  final DateTime createdAt;

  const CommunityInboxNotification({
    required this.kind,
    required this.eventId,
    required this.postId,
    required this.postContent,
    required this.actorNickname,
    required this.bodyText,
    required this.createdAt,
  });

  factory CommunityInboxNotification.fromMap(Map<String, dynamic> map) {
    final kindRaw = map['kind'] as String? ?? 'comment';
    return CommunityInboxNotification(
      kind: kindRaw == 'like'
          ? CommunityInboxKind.like
          : CommunityInboxKind.comment,
      eventId: map['event_id'] as String? ?? map['comment_id'] as String? ?? '',
      postId: map['post_id'] as String,
      postContent: map['post_content'] as String? ?? '',
      actorNickname: map['actor_nickname'] as String? ??
          map['commenter_nickname'] as String? ??
          '탈퇴한 사용자',
      bodyText: map['body_text'] as String? ??
          map['comment_content'] as String? ??
          '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get headlineSuffix =>
      kind == CommunityInboxKind.like ? '님이 좋아요를 눌렀어요' : '님이 댓글을 남겼어요';
}
