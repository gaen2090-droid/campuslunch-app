class RecentCrowdReport {
  final String id;
  final String status;
  final String source;
  final DateTime createdAt;
  final String? userId;

  const RecentCrowdReport({
    required this.id,
    required this.status,
    required this.source,
    required this.createdAt,
    this.userId,
  });

  bool get isOwner => source == 'owner';
  bool get isUser => source == 'user';
}
