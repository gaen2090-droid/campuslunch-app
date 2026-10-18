import '../models/crowd_prediction.dart';
import '../models/restaurant.dart';

/// 예측이 화면에 보이는 시간: 평일 11:30 이상 13:00 미만.
const int predictionStartMinute = 11 * 60 + 30;
const int predictionEndMinute = 13 * 60;

/// 앱이 예측을 새로 받아오기 시작하는 시각(11:30 구간이 열리기 전에 미리 받아 둔다).
const int predictionFetchStartMinute = 11 * 60 + 20;

/// 제보가 이 시간보다 오래되면 "오래된 제보"로 보고 예측을 대신 보여준다.
/// 홈 상태 섹션의 `30분 이상 지난 제보예요.` 기준과 같다.
const int predictionStaleMinutes = 30;

int _minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

bool _isWeekday(DateTime t) =>
    t.weekday >= DateTime.monday && t.weekday <= DateTime.friday;

/// 지금 예측을 화면에 보여줘도 되는 시간인가.
bool isPredictionWindow(DateTime now) {
  if (!_isWeekday(now)) return false;
  final m = _minuteOfDay(now);
  return m >= predictionStartMinute && m < predictionEndMinute;
}

/// 서버에 예측을 물어볼 시간인가(화면 노출 시간 + 앞 10분).
bool isPredictionFetchWindow(DateTime now) {
  if (!_isWeekday(now)) return false;
  final m = _minuteOfDay(now);
  return m >= predictionFetchStartMinute && m < predictionEndMinute;
}

/// 지금 시각이 속한 15분 구간의 시작(자정 기준 분). 노출 시간 밖이면 null.
int? predictionSlotStart(DateTime now) {
  if (!isPredictionWindow(now)) return null;
  return predictionStartMinute +
      (_minuteOfDay(now) - predictionStartMinute) ~/ 15 * 15;
}

/// 이 매장에 예측을 보여줄 수 있는가 (예측 값이 있는지는 따로 본다).
///
/// - 오늘 제보가 0건이거나, 마지막 제보가 30분을 넘었으면 대상이다.
/// - 30분 이내 제보(사장님 좌석 입력 포함)가 있으면 그 제보를 그대로 보여주므로 대상이 아니다.
/// - 영업안함이거나 제보를 받지 않는 매장은 대상이 아니다.
bool isPredictionTarget(Restaurant r, DateTime now) {
  if (!r.crowdEnabled || r.status == '영업안함') return false;
  if (!r.hasCrowdUpdate) return true;
  final at = r.updatedAt;
  if (at == null) return false;
  return now.difference(at).inMinutes > predictionStaleMinutes;
}

/// [list] 중 지금 예측이 붙는 매장만 모아 매장 id → 예측 으로 돌려준다.
/// [lookup] 은 보통 AppProvider.predictionFor.
Map<String, CrowdPrediction> collectPredictions(
  Iterable<Restaurant> list,
  CrowdPrediction? Function(Restaurant) lookup,
) {
  final result = <String, CrowdPrediction>{};
  for (final r in list) {
    final p = lookup(r);
    if (p != null) result[r.id] = p;
  }
  return result;
}

/// 섹션 [level](1=바로입장, 2=약간혼잡, 3=자리없음)에 들어갈 예측 매장.
/// 확률이 높은 순, 같으면 가까운 순이다. 확정 제보 매장 뒤에 이어 붙이는 용도.
List<Restaurant> predictedForLevel(
  Iterable<Restaurant> list,
  Map<String, CrowdPrediction> predictions,
  int level,
) {
  final result = list.where((r) => predictions[r.id]?.level == level).toList();
  result.sort((a, b) {
    final byProbability =
        predictions[b.id]!.relaxProbability.compareTo(predictions[a.id]!.relaxProbability);
    if (byProbability != 0) return byProbability;
    return a.distance.compareTo(b.distance);
  });
  return result;
}
