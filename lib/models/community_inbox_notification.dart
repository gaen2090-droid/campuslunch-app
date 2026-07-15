/// 커뮤니티 인박스 (댓글 + 좋아요 + 관리자 삭제 알림)
enum CommunityInboxKind {
  comment,
  like,
  adminPost,
  adminComment,
  adminCollection,
}

class CommunityInboxNotification {
  final CommunityInboxKind kind;
  final String eventId;
  final String? postId;
  final String postContent;
  final String actorNickname;
  final String bodyText;
  final DateTime createdAt;
  final bool isRead;

  const CommunityInboxNotification({
    required this.kind,
    required this.eventId,
    required this.postId,
    required this.postContent,
    required this.actorNickname,
    required this.bodyText,
    required this.createdAt,
    required this.isRead,
  });

  factory CommunityInboxNotification.fromMap(Map<String, dynamic> map) {
    final kindRaw = map['kind'] as String? ?? 'comment';
    final kind = switch (kindRaw) {
      'like' => CommunityInboxKind.like,
      'admin_post' => CommunityInboxKind.adminPost,
      'admin_comment' => CommunityInboxKind.adminComment,
      'admin_collection' => CommunityInboxKind.adminCollection,
      _ => CommunityInboxKind.comment,
    };
    return CommunityInboxNotification(
      kind: kind,
      eventId: map['event_id'] as String? ?? map['comment_id'] as String? ?? '',
      postId: map['post_id'] as String?,
      postContent: map['post_content'] as String? ?? '',
      actorNickname: map['actor_nickname'] as String? ??
          map['commenter_nickname'] as String? ??
          '탈퇴한 사용자',
      bodyText: map['body_text'] as String? ??
          map['comment_content'] as String? ??
          '',
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead: map['is_read'] as bool? ?? false,
    );
  }

  CommunityInboxNotification copyWith({bool? isRead}) {
    return CommunityInboxNotification(
      kind: kind,
      eventId: eventId,
      postId: postId,
      postContent: postContent,
      actorNickname: actorNickname,
      bodyText: bodyText,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  bool get isAdminNotice =>
      kind == CommunityInboxKind.adminPost ||
      kind == CommunityInboxKind.adminComment ||
      kind == CommunityInboxKind.adminCollection;

  String get headlineSuffix =>
      kind == CommunityInboxKind.like ? '님이 좋아요를 눌렀어요' : '님이 댓글을 남겼어요';

  String get adminHeadline => switch (kind) {
        CommunityInboxKind.adminPost => '운영정책 위반으로 내 글이 삭제됐어요.',
        CommunityInboxKind.adminComment => '운영정책 위반으로 내 댓글이 삭제됐어요.',
        CommunityInboxKind.adminCollection => '관리자에 의해 내가 등록한 컬렉션이 삭제됐어요.',
        _ => '',
      };

  static const _contentExcerptMaxChars = 10;

  String get _contentTypeLabel => switch (kind) {
        CommunityInboxKind.adminPost => '글',
        CommunityInboxKind.adminComment => '댓글',
        CommunityInboxKind.adminCollection => '컬렉션',
        _ => '',
      };

  /// 삭제된 글/댓글 원문 일부(10자 초과 시 말줄임). 원문이 없으면 표시 안 함.
  String? get adminContentText {
    final content = postContent.trim();
    if (content.isEmpty) return null;
    final truncated = content.length > _contentExcerptMaxChars
        ? '${content.substring(0, _contentExcerptMaxChars)}...'
        : content;
    return '$_contentTypeLabel 내용: $truncated';
  }

  /// 삭제 사유는 어드민에서 입력했을 때만 노출한다(입력 안 했으면 문구 자체를 표시하지 않음).
  String? get adminReasonText =>
      bodyText.trim().isEmpty ? null : '삭제 사유: $bodyText';
}
