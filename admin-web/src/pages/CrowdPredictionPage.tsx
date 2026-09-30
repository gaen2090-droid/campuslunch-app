import { useMemo } from "react";
import { MetricCard } from "../components/MetricCard";
import {
  CROWD_PREDICTION_SLOT_MINUTES,
  computeCoverage,
  estimateDaysToReady,
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
  const statusClass =
    slot.predictedStatus === "자리없음"
      ? "danger"
      : slot.predictedStatus === "약간혼잡"
        ? "warning"
        : "assigned";
  return (
    <td>
      <div className="crowd-prediction-cell">
        <span className={`badge ${statusClass}`}>{slot.predictedStatus}</span>
        <span className="crowd-prediction-n">n={slot.sampleSize}</span>
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
          점심시간(12:00~13:00, 평일) 제보를 15분 단위로 모아 매장별 대표
          혼잡도를 통계로 낸 화면입니다. 실제 학습 모델이 아니라 제보
          누적치 기반 통계 집계이며, 구간당 유효 제보가 {MIN_SAMPLE_SIZE}건
          미만이면 "데이터 부족"으로 표시합니다. 앱 화면에는 아직 노출되지
          않습니다.
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
