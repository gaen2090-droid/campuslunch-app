class DashboardMetrics {
  final int todayReports;
  final List<int> dailyReports; // 최근 7일 (오래된 순)
  final List<(String, int)> topReporters; // (userId, count)

  const DashboardMetrics({
    required this.todayReports,
    required this.dailyReports,
    required this.topReporters,
  });

  static const empty = DashboardMetrics(
    todayReports: 0,
    dailyReports: [0, 0, 0, 0, 0, 0, 0],
    topReporters: [],
  );
}
