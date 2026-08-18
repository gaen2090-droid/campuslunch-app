/// 커뮤니티 인박스 (댓글 + 답글 + 좋아요 + 관리자 삭제/정지 알림)
enum CommunityInboxKind {
  comment,
  reply,
  like,
  adminPost,
  adminComment,
  adminCollection,
  communitySuspend,
  reportSuspend,
  communityUnsuspend,
  reportUnsuspend,
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
  final bool isCollection;
  final DateTime? suspendedUntil;

  const CommunityInboxNotification({
    required this.kind,
    required this.eventId,
    required this.postId,
    required this.postContent,
    required this.actorNickname,
    required this.bodyText,
    required this.createdAt,
    required this.isRead,
    this.isCollection = false,
    this.suspendedUntil,
  });

  factory CommunityInboxNotification.fromMap(
    Map<String, dynamic> map, {
    bool isCollection = false,
  }) {
    final kindRaw = map['kind'] as String? ?? 'comment';
    final kind = switch (kindRaw) {
      'reply' => CommunityInboxKind.reply,
      'like' => CommunityInboxKind.like,
      'admin_post' => CommunityInboxKind.adminPost,
      'admin_comment' => CommunityInboxKind.adminComment,
      'admin_collection' => CommunityInboxKind.adminCollection,
      'community_suspend' => CommunityInboxKind.communitySuspend,
      'report_suspend' => CommunityInboxKind.reportSuspend,
      'community_unsuspend' => CommunityInboxKind.communityUnsuspend,
      'report_unsuspend' => CommunityInboxKind.reportUnsuspend,
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
      isCollection: isCollection,
      suspendedUntil: map['suspended_until'] != null
          ? DateTime.tryParse(map['suspended_until'] as String)
          : null,
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
      isCollection: isCollection,
      suspendedUntil: suspendedUntil,
    );
  }

  bool get isAdminNotice =>
      kind == CommunityInboxKind.adminPost ||
      kind == CommunityInboxKind.adminComment ||
      kind == CommunityInboxKind.adminCollection ||
      isSuspensionNotice;

  /// 정지/해제 알림 — 삭제 알림과 달리 원문이 없으므로 별도로 구분한다.
  bool get isSuspensionNotice =>
      kind == CommunityInboxKind.communitySuspend ||
      kind == CommunityInboxKind.reportSuspend ||
      kind == CommunityInboxKind.communityUnsuspend ||
      kind == CommunityInboxKind.reportUnsuspend;

  /// 정지 알림(해제 아님)만 — 빨간 배경으로 강조 표시할 대상.
  bool get isActiveSuspensionNotice =>
      kind == CommunityInboxKind.communitySuspend ||
      kind == CommunityInboxKind.reportSuspend;

  String get headlineSuffix => switch (kind) {
        CommunityInboxKind.like => '님이 좋아요를 눌렀어요',
        CommunityInboxKind.reply => '님이 답글을 남겼어요',
        _ => '님이 댓글을 남겼어요',
      };

  /// 정지 알림에 붙는 "n일간" 접미사. suspendedUntil이 없으면(구버전 데이터 등) 빈 문자열.
  String get _suspensionDaysSuffix {
    if (suspendedUntil == null) return '';
    final days = suspendedUntil!.difference(createdAt).inHours / 24;
    final rounded = days.round();
    return '${rounded < 1 ? 1 : rounded}일간 ';
  }

  String get adminHeadline => switch (kind) {
        CommunityInboxKind.adminPost => '운영정책 위반으로 내 글이 삭제됐어요.',
        CommunityInboxKind.adminComment => '운영정책 위반으로 내 댓글이 삭제됐어요.',
        CommunityInboxKind.adminCollection => '관리자에 의해 내가 등록한 컬렉션이 삭제됐어요.',
        CommunityInboxKind.communitySuspend =>
          '운영정책 위반으로 커뮤니티 이용이\n$_suspensionDaysSuffix정지됐어요.',
        CommunityInboxKind.reportSuspend =>
          '운영정책 위반으로 제보 기능 이용이\n$_suspensionDaysSuffix정지됐어요.',
        CommunityInboxKind.communityUnsuspend => '커뮤니티 이용 정지가 해제됐어요.',
        CommunityInboxKind.reportUnsuspend => '제보 기능 이용 정지가 해제됐어요.',
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
    if (isSuspensionNotice) return null;
    final content = postContent.trim();
    if (content.isEmpty) return null;
    final truncated = content.length > _contentExcerptMaxChars
        ? '${content.substring(0, _contentExcerptMaxChars)}...'
        : content;
    return '$_contentTypeLabel 내용: $truncated';
  }

  /// 삭제/정지 사유는 어드민에서 입력했을 때만 노출한다(입력 안 했으면 문구 자체를 표시하지 않음).
  String? get adminReasonText {
    if (bodyText.trim().isEmpty) return null;
    return isActiveSuspensionNotice ? '정지 사유: $bodyText' : '삭제 사유: $bodyText';
  }
}
