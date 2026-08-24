class MenuItem {
  final String name;
  final int price;

  const MenuItem({required this.name, required this.price});

  factory MenuItem.fromMap(Map<String, dynamic> m) => MenuItem(
        name: m['name'] as String? ?? '',
        price: (m['price'] as num?)?.round() ?? 0,
      );

  Map<String, dynamic> toMap() => {'name': name, 'price': price};
}

class Restaurant {
  final String id;
  /// App Link 경로 번호 (/r/{linkNo}). DB INSERT 시 자동 배정.
  final int linkNo;
  final String name;
  final String category;
  final String area;
  final String address;
  String status;
  int updated;
  final String imageUrl;
  final int popularityScore;
  final int manualRank;
  final String? ownerId;
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
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final DateTime? ownerUpdatedAt;
  /// DB is_active. 일반 앱 목록은 true 만 로드, 어드민은 false 포함 가능.
  final bool isActive;
  /// DB crowd_enabled. false면 맛집컬렉션 전용 매장 — 지도/홈 평소 목록·혼잡도 제보 기능 없음.
  final bool crowdEnabled;
  /// 사장님이 직접 등록한 메뉴 사진 (최대 3장)
  final List<String> menuPhotoUrls;
  /// 대표사진(imageUrl) 출처. 'owner' | 'google' (기본값 'google')
  final String imageSource;
  /// 사장님이 대표사진을 처음 교체할 때 보존해둔 원본 구글 사진 URL.
  /// 비어있으면 "구글맵 사진으로 되돌리기"를 보여줄 수 없음(보존값 없음).
  final String googleImageUrl;
  /// 사장님이 직접 입력한 매장 공지 (최대 500자)
  final String ownerNotice;

  Restaurant({
    required this.id,
    this.linkNo = 0,
    required this.name,
    required this.category,
    required this.area,
    required this.address,
    required this.status,
    required this.updated,
    required this.imageUrl,
    this.popularityScore = 0,
    this.manualRank = 0,
    this.ownerId,
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
    this.updatedAt,
    this.createdAt,
    this.ownerUpdatedAt,
    this.isActive = true,
    this.crowdEnabled = true,
    this.menuPhotoUrls = const [],
    this.imageSource = 'google',
    this.googleImageUrl = '',
    this.ownerNotice = '',
  });

  Restaurant copyWith({
    String? status,
    int? updated,
    Map<String, int>? reports,
    String? crowdBaseSource,
    String? crowdConfidence,
    bool? hasCrowdUpdate,
    double? distance,
    String? imageUrl,
    String? imageSource,
    String? googleImageUrl,
    List<String>? menuPhotoUrls,
    List<MenuItem>? menu,
    String? hours,
    String? ownerNotice,
  }) =>
      Restaurant(
        id: id,
        linkNo: linkNo,
        name: name,
        category: category,
        area: area,
        address: address,
        status: status ?? this.status,
        updated: updated ?? this.updated,
        imageUrl: imageUrl ?? this.imageUrl,
        popularityScore: popularityScore,
        manualRank: manualRank,
        ownerId: ownerId,
        distance: distance ?? this.distance,
        latitude: latitude,
        longitude: longitude,
        x: x,
        y: y,
        hours: hours ?? this.hours,
        hoursPeriods: hoursPeriods,
        reports: reports ?? Map.from(this.reports),
        menu: menu ?? this.menu,
        crowdBaseSource: crowdBaseSource ?? this.crowdBaseSource,
        crowdConfidence: crowdConfidence ?? this.crowdConfidence,
        hasCrowdUpdate: hasCrowdUpdate ?? this.hasCrowdUpdate,
        updatedAt: updatedAt,
        createdAt: createdAt,
        ownerUpdatedAt: ownerUpdatedAt,
        isActive: isActive,
        crowdEnabled: crowdEnabled,
        menuPhotoUrls: menuPhotoUrls ?? this.menuPhotoUrls,
        imageSource: imageSource ?? this.imageSource,
        googleImageUrl: googleImageUrl ?? this.googleImageUrl,
        ownerNotice: ownerNotice ?? this.ownerNotice,
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
  '여유로움': StatusMeta(label: '여유로움', color: 0xFF26BC7D, bgColor: 0xFFE6F3EC),
  '약간혼잡': StatusMeta(label: '약간혼잡', color: 0xFFF59E0B, bgColor: 0xFFFEF3C7),
  // 자리없음: 빨강 — 약간혼잡(노란 앰버)과 명확히 구분
  '자리없음': StatusMeta(label: '자리없음', color: 0xFFEF4444, bgColor: 0xFFFEE2E2),
  '영업안함': StatusMeta(label: '영업안함', color: 0xFF9CA3AF, bgColor: 0xFFF3F4F6),
  '제보필요': StatusMeta(label: '제보필요', color: 0xFF000000, bgColor: 0xFFF3F4F6),
};

StatusMeta crowdStatusMeta(String status) =>
    statusMetaMap[status] ??
    const StatusMeta(
      label: '알 수 없음',
      color: 0xFF9CA3AF,
      bgColor: 0xFFF3F4F6,
    );
