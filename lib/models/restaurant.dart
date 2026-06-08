class MenuItem {
  final String name;
  final int price;

  const MenuItem({required this.name, required this.price});

  factory MenuItem.fromMap(Map<String, dynamic> m) =>
      MenuItem(name: m['name'] as String, price: m['price'] as int);

  Map<String, dynamic> toMap() => {'name': name, 'price': price};
}

class Restaurant {
  final String id;
  final String name;
  final String category;
  final String area;
  final String address;
  String status;
  int updated;
  final String imageUrl;
  final int popularityScore;
  final int manualRank;
  final String ownerCode;
  final bool ownerRegistered;
  final double distance;
  final double latitude;
  final double longitude;
  final double x;
  final double y;
  final String hours;
  /// Google Places `opening_hours.periods` (요일별 영업 판단용)
  final List<Map<String, dynamic>> hoursPeriods;
  Map<String, int> reports;
  final List<MenuItem> menu;
  final String crowdBaseSource;
  final String crowdConfidence;
  /// crowd_status 행 기준 실제 업데이트가 있을 때만 `n분 전 업데이트` 표시
  final bool hasCrowdUpdate;
  final DateTime? createdAt;
  final DateTime? ownerUpdatedAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.address,
    required this.status,
    required this.updated,
    required this.imageUrl,
    this.popularityScore = 0,
    this.manualRank = 0,
    this.ownerCode = '',
    this.ownerRegistered = false,
    required this.distance,
    this.latitude = 0,
    this.longitude = 0,
    required this.x,
    required this.y,
    required this.hours,
    this.hoursPeriods = const [],
    required this.reports,
    required this.menu,
    this.crowdBaseSource = '',
    this.crowdConfidence = '',
    this.hasCrowdUpdate = true,
    this.createdAt,
    this.ownerUpdatedAt,
  });

  Restaurant copyWith({
    String? status,
    int? updated,
    Map<String, int>? reports,
    String? crowdBaseSource,
    String? crowdConfidence,
    bool? hasCrowdUpdate,
  }) =>
      Restaurant(
        id: id,
        name: name,
        category: category,
        area: area,
        address: address,
        status: status ?? this.status,
        updated: updated ?? this.updated,
        imageUrl: imageUrl,
        popularityScore: popularityScore,
        manualRank: manualRank,
        ownerCode: ownerCode,
        ownerRegistered: ownerRegistered,
        distance: distance,
        latitude: latitude,
        longitude: longitude,
        x: x,
        y: y,
        hours: hours,
        hoursPeriods: hoursPeriods,
        reports: reports ?? Map.from(this.reports),
        menu: menu,
        crowdBaseSource: crowdBaseSource ?? this.crowdBaseSource,
        crowdConfidence: crowdConfidence ?? this.crowdConfidence,
        hasCrowdUpdate: hasCrowdUpdate ?? this.hasCrowdUpdate,
        createdAt: createdAt,
        ownerUpdatedAt: ownerUpdatedAt,
      );

  int get totalReports =>
      reports.values.fold(0, (sum, v) => sum + v);

  bool get hasMapLocation =>
      latitude.abs() > 0.0001 && longitude.abs() > 0.0001;
}

class StatusMeta {
  final String label;
  final int color;
  final int bgColor;

  const StatusMeta({
    required this.label,
    required this.color,
    required this.bgColor,
  });
}

const Map<String, StatusMeta> statusMetaMap = {
  '여유로움': StatusMeta(label: '여유로움', color: 0xFF22C55E, bgColor: 0xFFDCFCE7),
  '약간혼잡': StatusMeta(label: '약간혼잡', color: 0xFFF59E0B, bgColor: 0xFFFEF3C7),
  '자리없음': StatusMeta(label: '자리없음', color: 0xFFEF4444, bgColor: 0xFFFEE2E2),
  '영업안함': StatusMeta(label: '영업안함', color: 0xFF9CA3AF, bgColor: 0xFFF3F4F6),
};

StatusMeta crowdStatusMeta(String status) =>
    statusMetaMap[status] ??
    const StatusMeta(
      label: '알 수 없음',
      color: 0xFF9CA3AF,
      bgColor: 0xFFF3F4F6,
    );
