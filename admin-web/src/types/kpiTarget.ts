export type KpiMetricKey =
  | "new_users"
  | "lunch_dau"
  | "wau"
  | "reports"
  | "report_participants"
  | "coverage";

/** 누적형: 이번 달 누적값 / 목표. 평균형: 이번 달(현재까지) 일평균 / 목표 일평균. */
export type KpiMetricKind = "cumulative" | "average";

export interface KpiTarget {
  metricKey: KpiMetricKey;
  periodMonth: Date;
  targetValue: number;
}

export const KPI_METRIC_LABELS: Record<KpiMetricKey, string> = {
  new_users: "신규 가입자",
  lunch_dau: "점심시간 일평균 사용자",
  wau: "WAU",
  reports: "제보 건수",
  report_participants: "일평균 제보 참여자",
  coverage: "실시간 혼잡도 커버리지",
};

export const KPI_METRIC_KIND: Record<KpiMetricKey, KpiMetricKind> = {
  new_users: "cumulative",
  lunch_dau: "average",
  wau: "cumulative",
  reports: "cumulative",
  report_participants: "average",
  coverage: "average",
};

export const KPI_METRIC_UNIT: Record<KpiMetricKey, string> = {
  new_users: "명",
  lunch_dau: "명",
  wau: "명",
  reports: "건",
  report_participants: "명",
  coverage: "%",
};

export function parseKpiTarget(raw: Record<string, unknown>): KpiTarget {
  return {
    metricKey: String(raw.metric_key) as KpiMetricKey,
    periodMonth: new Date(String(raw.period_month)),
    targetValue: Number(raw.target_value ?? 0),
  };
}

/** "YYYY-M" 형태의 월 키 (metrics.ts의 monthKey와 동일 규칙) */
export function monthKeyOf(date: Date): string {
  return `${date.getFullYear()}-${date.getMonth() + 1}`;
}

export function currentMonthKey(): string {
  return monthKeyOf(new Date());
}
