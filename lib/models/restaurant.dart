class MenuItem {
  final String name;
  final int price;

  const MenuItem({required this.name, required this.price});

  factory MenuItem.fromMap(Map<String, dynamic> m) =>
      MenuItem(name: m['name'] as String, price: m['price'] as int);

  Map<String, dynamic> toMap() => {'name': name, 'price': price};
}

class Restaurant {
  final int id;
  final String name;
  final String category;
  final String area;
  final String address;
  String status;
  int updated;
  final String emoji;
  final String imageUrl;
  final double distance;
  final double x;
  final double y;
  final String hours;
  Map<String, int> reports;
  final List<MenuItem> menu;

  Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.address,
    required this.status,
    required this.updated,
    required this.emoji,
    required this.imageUrl,
    required this.distance,
    required this.x,
    required this.y,
    required this.hours,
    required this.reports,
    required this.menu,
  });

  Restaurant copyWith({
    String? status,
    int? updated,
    Map<String, int>? reports,
  }) =>
      Restaurant(
        id: id,
        name: name,
        category: category,
        area: area,
        address: address,
        status: status ?? this.status,
        updated: updated ?? this.updated,
        emoji: emoji,
        imageUrl: imageUrl,
        distance: distance,
        x: x,
        y: y,
        hours: hours,
        reports: reports ?? Map.from(this.reports),
        menu: menu,
      );

  int get totalReports =>
      reports.values.fold(0, (sum, v) => sum + v);
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
