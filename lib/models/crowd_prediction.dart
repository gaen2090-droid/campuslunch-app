/// 서버가 계산해서 내려주는 매장별 혼잡도 예측 (현재 15분 구간 기준).
class CrowdPrediction {
  const CrowdPrediction({
    required this.restaurantId,
    required this.slotStartMinute,
    required this.sampleSize,
    required this.relaxProbability,
    required this.level,
  });

  final String restaurantId;

  /// 자정 기준 분. 690=11:30 … 765=12:45
  final int slotStartMinute;

  /// 그 구간에 모인 제보 수 (서버는 3건 이상일 때만 내려준다)
  final int sampleSize;

  /// 여유로울 확률(%)
  final int relaxProbability;

  /// 1=여유로움(화면 표기 바로입장, 70%+) · 2=약간혼잡(40~69%) · 3=자리없음(40% 미만).
  /// 기준값은 서버가 확률로 정해서 내려준다.
  final int level;

  /// Restaurant.status 와 같은 문자열
  String get status => switch (level) {
        1 => '여유로움',
        2 => '약간혼잡',
        _ => '자리없음',
      };

  factory CrowdPrediction.fromMap(Map<dynamic, dynamic> row) => CrowdPrediction(
        restaurantId: row['restaurant_id'].toString(),
        slotStartMinute: (row['slot_start_minute'] as num).toInt(),
        sampleSize: (row['sample_size'] as num).toInt(),
        relaxProbability: (row['relax_probability'] as num).toInt(),
        level: (row['prob_level'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is CrowdPrediction &&
      other.restaurantId == restaurantId &&
      other.slotStartMinute == slotStartMinute &&
      other.sampleSize == sampleSize &&
      other.relaxProbability == relaxProbability &&
      other.level == level;

  @override
  int get hashCode => Object.hash(
        restaurantId,
        slotStartMinute,
        sampleSize,
        relaxProbability,
        level,
      );
}
