class CommunityNotice {
  final String id;
  final String content;

  const CommunityNotice({required this.id, required this.content});

  factory CommunityNotice.fromMap(Map<String, dynamic> map) {
    return CommunityNotice(
      id: map['id'] as String,
      content: map['content'] as String,
    );
  }
}
