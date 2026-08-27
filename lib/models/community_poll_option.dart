class CommunityPollOption {
  final String id;
  final String label;
  final int sortOrder;
  final int voteCount;
  final bool votedByMe;
  final bool allowMultiple;

  const CommunityPollOption({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.voteCount,
    required this.votedByMe,
    required this.allowMultiple,
  });

  factory CommunityPollOption.fromMap(Map<String, dynamic> map) {
    return CommunityPollOption(
      id: map['id'] as String,
      label: map['label'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      voteCount: map['vote_count'] as int? ?? 0,
      votedByMe: map['voted_by_me'] as bool? ?? false,
      allowMultiple: map['allow_multiple'] as bool? ?? false,
    );
  }
}
