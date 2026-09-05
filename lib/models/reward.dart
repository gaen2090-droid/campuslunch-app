class UserReward {
  final int totalStamps;
  final int todayStamps;
  final DateTime? lastStampDate;

  const UserReward({
    this.totalStamps = 0,
    this.todayStamps = 0,
    this.lastStampDate,
  });

  factory UserReward.fromJson(Map<String, dynamic> json) {
    return UserReward(
      totalStamps: (json['total_stamps'] as num?)?.toInt() ?? 0,
      todayStamps: (json['today_stamps'] as num?)?.toInt() ?? 0,
      lastStampDate: json['last_stamp_date'] != null
          ? DateTime.tryParse(json['last_stamp_date'] as String)
          : null,
    );
  }

  static const UserReward empty = UserReward();
}

class StampResult {
  final bool granted;
  final int grantedCount;
  final int todayStamps;
  final int totalStamps;
  final AutoRedeemResult autoRedeem;
  final String? reason;

  const StampResult({
    required this.granted,
    this.grantedCount = 0,
    required this.todayStamps,
    required this.totalStamps,
    this.autoRedeem = AutoRedeemResult.none,
    this.reason,
  });

  bool get isOutOfStampHours => reason == 'out_of_hours';
  bool get isWeekend => reason == 'weekend';

  factory StampResult.fromJson(Map<String, dynamic> json) {
    final granted = json['granted'] as bool? ?? false;
    final autoRaw = json['auto_redeem'];
    AutoRedeemResult auto = AutoRedeemResult.none;
    if (autoRaw is Map) {
      auto = AutoRedeemResult.fromJson(Map<String, dynamic>.from(autoRaw));
    }
    return StampResult(
      granted: granted,
      grantedCount: (json['granted_count'] as num?)?.toInt() ?? (granted ? 1 : 0),
      todayStamps: (json['today_stamps'] as num?)?.toInt() ?? 0,
      totalStamps: (json['total_stamps'] as num?)?.toInt() ?? 0,
      autoRedeem: auto,
      reason: json['reason'] as String?,
    );
  }

  static const StampResult none = StampResult(
    granted: false,
    grantedCount: 0,
    todayStamps: 0,
    totalStamps: 0,
  );
}

class AutoRedeemResult {
  final String status;
  final String? brand;
  final String? productName;

  const AutoRedeemResult({
    required this.status,
    this.brand,
    this.productName,
  });

  bool get succeeded => status == 'ok';

  factory AutoRedeemResult.fromJson(Map<String, dynamic> json) {
    return AutoRedeemResult(
      status: json['status'] as String? ?? 'none',
      brand: json['brand'] as String?,
      productName: json['product_name'] as String?,
    );
  }

  static const AutoRedeemResult none =
      AutoRedeemResult(status: 'none');
}

class Gifticon {
  final String id;
  final String brand;
  final String productName;
  final String imageUrl;
  final DateTime? expiresAt;
  final String status; // unassigned | assigned | expired | used
  final String? assignedUserId;
  final DateTime? assignedAt;
  final String? couponCode;
  final DateTime createdAt;

  const Gifticon({
    required this.id,
    required this.brand,
    required this.productName,
    required this.imageUrl,
    this.expiresAt,
    required this.status,
    this.assignedUserId,
    this.assignedAt,
    this.couponCode,
    required this.createdAt,
  });

  factory Gifticon.fromJson(Map<String, dynamic> json) {
    return Gifticon(
      id: json['id'] as String,
      brand: json['brand'] as String,
      productName: json['product_name'] as String,
      imageUrl: json['image_url'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      status: json['status'] as String? ?? 'unassigned',
      assignedUserId: json['assigned_user_id'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'] as String)
          : null,
      couponCode: json['coupon_code'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'assigned':
        return '배정됨';
      case 'used':
        return '사용됨';
      case 'expired':
        return '만료';
      default:
        return '미배정';
    }
  }

  String get expiresLabel {
    if (expiresAt == null) return '';
    return '${expiresAt!.year}.${expiresAt!.month.toString().padLeft(2, '0')}.${expiresAt!.day.toString().padLeft(2, '0')}';
  }
}

enum RedeemResult { ok, notEnough, soldOut, error }
