class DashboardMetrics {
  final int dauToday;
  final int mau;
  final List<int> dailyDau;
  final List<int> monthlyMau;
  final int todayReports;
  final int weekReports;
  final double bannerClickRate;
  final List<double> dailyClickRates;
  final double pushOpenRate;
  final List<double> dailyPushOpenRates;
  final List<(String, int)> topReporters;
  final Map<String, int> todayByRestaurant;
  final Map<String, int> weekByRestaurant;

  const DashboardMetrics({
    required this.dauToday,
    required this.mau,
    required this.dailyDau,
    required this.monthlyMau,
    required this.todayReports,
    required this.weekReports,
    required this.bannerClickRate,
    required this.dailyClickRates,
    required this.pushOpenRate,
    required this.dailyPushOpenRates,
    required this.topReporters,
    required this.todayByRestaurant,
    required this.weekByRestaurant,
  });

  int get weekTotal => weekReports;

  static const empty = DashboardMetrics(
    dauToday: 0,
    mau: 0,
    dailyDau: [0, 0, 0, 0, 0, 0, 0],
    monthlyMau: [0, 0, 0, 0, 0, 0],
    todayReports: 0,
    weekReports: 0,
    bannerClickRate: 0,
    dailyClickRates: [0, 0, 0, 0, 0, 0, 0],
    pushOpenRate: 0,
    dailyPushOpenRates: [0, 0, 0, 0, 0, 0, 0],
    topReporters: [],
    todayByRestaurant: {},
    weekByRestaurant: {},
  );
}
