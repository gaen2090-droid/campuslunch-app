class DashboardMetrics {
  final int todayReports;
  final List<int> dailyReports; // 최근 7일 (오래된 순)
  final List<(String, int)> topReporters;
  final Map<String, int> todayByRestaurant;  // restaurant_id → 오늘 제보 수
  final Map<String, int> weekByRestaurant;   // restaurant_id → 최근 7일 제보 수

  const DashboardMetrics({
    required this.todayReports,
    required this.dailyReports,
    required this.topReporters,
    required this.todayByRestaurant,
    required this.weekByRestaurant,
  });

  int get weekTotal =>
      weekByRestaurant.values.fold(0, (s, v) => s + v);

  static const empty = DashboardMetrics(
    todayReports: 0,
    dailyReports: [0, 0, 0, 0, 0, 0, 0],
    topReporters: [],
    todayByRestaurant: {},
    weekByRestaurant: {},
  );
}
