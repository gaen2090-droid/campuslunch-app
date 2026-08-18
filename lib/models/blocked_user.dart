class BlockedUser {
  final String userId;
  final String nickname;
  final DateTime createdAt;

  const BlockedUser({
    required this.userId,
    required this.nickname,
    required this.createdAt,
  });

  factory BlockedUser.fromMap(Map<String, dynamic> map) {
    return BlockedUser(
      userId: map['user_id'] as String,
      nickname: map['nickname'] as String? ?? '탈퇴한 사용자',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
