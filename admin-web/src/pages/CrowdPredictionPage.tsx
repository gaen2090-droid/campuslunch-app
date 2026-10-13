import { useMemo } from "react";
import { MetricCard } from "../components/MetricCard";
import {
  CROWD_PREDICTION_SLOT_MINUTES,
  computeCoverage,
  estimateDaysToReady,
  seatAvailableProbability,
  slotLabel,
  type CrowdPredictionDailyCount,
  type CrowdPredictionRestaurant,
  type CrowdPredictionSlot,
} from "../types/crowdPrediction";

interface Props {
  restaurants: CrowdPredictionRestaurant[];
  dailyCounts: CrowdPredictionDailyCount[];
  loading: boolean;
  error: string | null;
  onReload: () => void;
}

const MIN_SAMPLE_SIZE = 3;
/** "자리 있을 확률" 뱃지 색 구간: 70% 이상 초록, 40~69% 주황, 40% 미만 빨강 (임의 기준, 조정 가능). */
const SEAT_PROB_HIGH = 70;
const SEAT_PROB_MID = 40;
/** 학습 모델(로지스틱 회귀 등)로 전환을 고려할 구간당 표본 기준(매장당
 * 4구간 합산 시 40건). "본격 신뢰"보다는 "일단 시도해볼 최소선". */
const READY_SAMPLE_SIZE = 10;

function slotForMinute(
  restaurant: CrowdPredictionRestaurant,
  minute: number,
): CrowdPredictionSlot | undefined {
  return restaurant.slots.find((s) => s.slotStartMinute === minute);
}

function SlotCell({ slot }: { slot: CrowdPredictionSlot | undefined }) {
  if (!slot || slot.sampleSize < MIN_SAMPLE_SIZE) {
    return (
      <td>
        <div className="crowd-prediction-cell">
          <span className="muted">데이터 부족</span>
          <span className="crowd-prediction-n">n={slot?.sampleSize ?? 0}</span>
        </div>
      </td>
    );
  }
  // 메인 지표는 "자리 있을 확률". 최빈값 뱃지는 표본이 적을 때 과하게 단정적이라 쓰지 않는다.
  const seatProb = seatAvailableProbability(slot) ?? 0;
  const probClass =
    seatProb >= SEAT_PROB_HIGH ? "assigned" : seatProb >= SEAT_PROB_MID ? "warning" : "danger";
  return (
    <td>
      <div className="crowd-prediction-cell">
        <span className={`badge ${probClass}`}>자리 있을 확률 {seatProb}%</span>
        <span className="crowd-prediction-n">
          입장가능 {slot.level1Count} · 약간혼잡 {slot.level2Count} · 자리없음{" "}
          {slot.level3Count} (n={slot.sampleSize})
        </span>
      </div>
    </td>
  );
}

export function CrowdPredictionPage({
  restaurants,
  dailyCounts,
  loading,
  error,
  onReload,
}: Props) {
  const coverage = useMemo(
    () => computeCoverage(restaurants, MIN_SAMPLE_SIZE),
    [restaurants],
  );
  const daysToReady = useMemo(
    () => estimateDaysToReady(dailyCounts, coverage, READY_SAMPLE_SIZE),
    [dailyCounts, coverage],
  );

  if (error) {
    return <div className="alert">{error}</div>;
  }

  return (
    <div className="dashboard">
      <section className="panel">
        <div className="panel-head">
          <h2>
            혼잡도 AI 예측 <span className="badge">베타</span>
          </h2>
          <button type="button" className="btn outline sm" onClick={onReload} disabled={loading}>
            새로고침
          </button>
        </div>
        <p className="muted">
          점심시간(12:00~13:00, 평일) 제보를 15분 단위로 모아 매장별로
          "자리 있을 확률"을 통계로 낸 화면입니다. 늦게 올라오는 제보를 위해
          구간 끝은 2분씩 겹쳐 적용합니다(마지막 구간은 13:02까지). 실제 학습
          모델이 아니라 제보 누적치 기반 통계 집계이며, 구간당 유효 제보가{" "}
          {MIN_SAMPLE_SIZE}건 미만이면 "데이터 부족"으로 표시합니다. "자리 있을
          확률"은 입장가능+약간혼잡 제보 비율(표본이 적을 때를 위해 보정)이고,
          {SEAT_PROB_HIGH}% 이상 초록 · {SEAT_PROB_MID}% 이상 주황 · 그 미만
          빨강으로 표시합니다. 앱 화면에는 아직 노출되지 않습니다.
        </p>
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>표본 추적</h2>
        </div>
        <p className="muted">
          구간당 표본이 {READY_SAMPLE_SIZE}건 정도 쌓이면 로지스틱 회귀 등
          학습 모델 도입을 검토할 만합니다. 최근 {dailyCounts.length}일
          평일 점심 제보 추이로 남은 기간을 추정합니다.
        </p>
        <div className="metric-grid">
          <MetricCard
            label="구간당 평균 표본"
            value={coverage.averageSampleSize.toFixed(1)}
            unit={`건 · 목표 ${READY_SAMPLE_SIZE}건`}
          />
          <MetricCard
            label="데이터 부족 구간 비율"
            value={`${Math.round(coverage.belowThresholdRatio * 100)}%`}
            unit={`전체 ${coverage.totalSlots}구간 중`}
          />
          <MetricCard
            label="학습 기준까지 예상 소요"
            value={daysToReady === null ? "추정 불가" : `${daysToReady}일`}
            unit={
              daysToReady === null
                ? "최근 제보 없음"
                : `최근 ${dailyCounts.length}일 평균 기준`
            }
          />
        </div>

        {(coverage.lowestRestaurants.length > 0 ||
          coverage.highestRestaurants.length > 0) && (
          <div className="table-wrap" style={{ marginTop: 16 }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>표본 적은 매장 (하위 5)</th>
                  <th>누적 n</th>
                  <th>표본 많은 매장 (상위 5)</th>
                  <th>누적 n</th>
                </tr>
              </thead>
              <tbody>
                {Array.from({ length: 5 }).map((_, i) => {
                  const low = coverage.lowestRestaurants[i];
                  const high = coverage.highestRestaurants[i];
                  return (
                    <tr key={i}>
                      <td>{low?.restaurantName ?? "—"}</td>
                      <td>{low ? low.totalSampleSize : "—"}</td>
                      <td>{high?.restaurantName ?? "—"}</td>
                      <td>{high ? high.totalSampleSize : "—"}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>매장별 예측</h2>
        </div>
        <p className="muted sm">
          구간은 끝이 2분씩 겹쳐 적용돼요. 예) 12:00~12:15 구간은 12:17까지의
          제보를 포함하고, 마지막 12:45~13:00 구간은 13:02까지 포함해요. 겹치는
          2분의 제보는 이웃한 두 구간에 모두 반영됩니다.
        </p>
        {loading && restaurants.length === 0 ? (
          <p className="muted center">불러오는 중…</p>
        ) : restaurants.length === 0 ? (
          <p className="muted center">제보 대상 매장이 없어요.</p>
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>매장명</th>
                  {CROWD_PREDICTION_SLOT_MINUTES.map((minute) => (
                    <th key={minute}>{slotLabel(minute)}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {restaurants.map((r) => (
                  <tr key={r.restaurantId}>
                    <td>{r.restaurantName}</td>
                    {CROWD_PREDICTION_SLOT_MINUTES.map((minute) => (
                      <SlotCell key={minute} slot={slotForMinute(r, minute)} />
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
