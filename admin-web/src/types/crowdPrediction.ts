/** 혼잡도 AI 예측 — admin_crowd_prediction_lunch() RPC 응답 1행 */
export interface CrowdPredictionSlot {
  restaurantId: string;
  restaurantName: string;
  /** 720=12:00, 735=12:15, 750=12:30, 765=12:45 (자정 기준 분) */
  slotStartMinute: number;
  sampleSize: number;
  /** 1=여유로움, 2=약간혼잡, 3=자리없음. 표본 부족(3건 미만) 시 null */
  predictedLevel: number | null;
  predictedStatus: string | null;
  level1Count: number;
  level2Count: number;
  level3Count: number;
}

/** 매장 하나의 4개 구간(12:00~13:00, 15분 단위) 묶음 */
export interface CrowdPredictionRestaurant {
  restaurantId: string;
  restaurantName: string;
  slots: CrowdPredictionSlot[];
}

export const CROWD_PREDICTION_SLOT_MINUTES = [720, 735, 750, 765] as const;

export function slotLabel(slotStartMinute: number): string {
  const h = Math.floor(slotStartMinute / 60);
  const m = slotStartMinute % 60;
  const endTotal = slotStartMinute + 15;
  const eh = Math.floor(endTotal / 60);
  const em = endTotal % 60;
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${pad(h)}:${pad(m)}~${pad(eh)}:${pad(em)}`;
}

function toNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" ? value : Number(value) || fallback;
}

function parseSlot(row: Record<string, unknown>): CrowdPredictionSlot {
  const predictedLevel = row.predicted_level;
  return {
    restaurantId: String(row.restaurant_id ?? ""),
    restaurantName: String(row.restaurant_name ?? ""),
    slotStartMinute: toNumber(row.slot_start_minute),
    sampleSize: toNumber(row.sample_size),
    predictedLevel:
      predictedLevel === null || predictedLevel === undefined
        ? null
        : toNumber(predictedLevel),
    predictedStatus:
      row.predicted_status === null || row.predicted_status === undefined
        ? null
        : String(row.predicted_status),
    level1Count: toNumber(row.level_1_count),
    level2Count: toNumber(row.level_2_count),
    level3Count: toNumber(row.level_3_count),
  };
}

/** admin_crowd_prediction_daily_counts() RPC 응답 1행 */
export interface CrowdPredictionDailyCount {
  reportDate: string; // YYYY-MM-DD
  validReportCount: number;
}

export function parseDailyCounts(rows: unknown[]): CrowdPredictionDailyCount[] {
  return rows.map((r) => {
    const row = r as Record<string, unknown>;
    return {
      reportDate: String(row.report_date ?? ""),
      validReportCount: toNumber(row.valid_report_count),
    };
  });
}

/** 표본 추적 요약 — 매장×구간 그리드(CrowdPredictionRestaurant[])에서 계산 */
export interface CrowdPredictionCoverage {
  totalSlots: number;
  averageSampleSize: number;
  belowThresholdRatio: number; // 0~1, n < minSampleSize 인 구간 비율
  lowestRestaurants: { restaurantName: string; totalSampleSize: number }[];
  highestRestaurants: { restaurantName: string; totalSampleSize: number }[];
}

export function computeCoverage(
  restaurants: CrowdPredictionRestaurant[],
  minSampleSize: number,
): CrowdPredictionCoverage {
  const allSlots = restaurants.flatMap((r) => r.slots);
  const totalSlots = allSlots.length;
  const totalSample = allSlots.reduce((sum, s) => sum + s.sampleSize, 0);
  const belowCount = allSlots.filter((s) => s.sampleSize < minSampleSize).length;

  const byRestaurant = restaurants
    .map((r) => ({
      restaurantName: r.restaurantName,
      totalSampleSize: r.slots.reduce((sum, s) => sum + s.sampleSize, 0),
    }))
    .sort((a, b) => a.totalSampleSize - b.totalSampleSize);

  return {
    totalSlots,
    averageSampleSize: totalSlots === 0 ? 0 : totalSample / totalSlots,
    belowThresholdRatio: totalSlots === 0 ? 0 : belowCount / totalSlots,
    lowestRestaurants: byRestaurant.slice(0, 5),
    highestRestaurants: [...byRestaurant].reverse().slice(0, 5),
  };
}

/** 학습 가능 기준(구간당 n)까지 남은 일수 추정 — 최근 daily counts의 하루 평균
 * 증가량으로 선형 추정. 매장 수·구간 수로 나눠 "구간 하나당" 증가 속도로 환산. */
export function estimateDaysToReady(
  dailyCounts: CrowdPredictionDailyCount[],
  coverage: CrowdPredictionCoverage,
  targetSampleSize: number,
): number | null {
  if (dailyCounts.length === 0 || coverage.totalSlots === 0) return null;
  const totalReports = dailyCounts.reduce((sum, d) => sum + d.validReportCount, 0);
  const avgPerDay = totalReports / dailyCounts.length;
  if (avgPerDay <= 0) return null;

  const avgPerDayPerSlot = avgPerDay / coverage.totalSlots;
  if (avgPerDayPerSlot <= 0) return null;

  const remaining = targetSampleSize - coverage.averageSampleSize;
  if (remaining <= 0) return 0;

  return Math.ceil(remaining / avgPerDayPerSlot);
}

/** RPC가 (매장×구간) flat rows로 주는 결과를 매장 단위로 묶는다 */
export function groupByRestaurant(
  rows: unknown[],
): CrowdPredictionRestaurant[] {
  const slots = rows.map((r) => parseSlot(r as Record<string, unknown>));
  const byRestaurant = new Map<string, CrowdPredictionRestaurant>();
  for (const slot of slots) {
    let entry = byRestaurant.get(slot.restaurantId);
    if (!entry) {
      entry = {
        restaurantId: slot.restaurantId,
        restaurantName: slot.restaurantName,
        slots: [],
      };
      byRestaurant.set(slot.restaurantId, entry);
    }
    entry.slots.push(slot);
  }
  return [...byRestaurant.values()].sort((a, b) =>
    a.restaurantName.localeCompare(b.restaurantName, "ko"),
  );
}
