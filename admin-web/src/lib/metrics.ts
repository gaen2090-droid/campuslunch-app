import { supabase } from "./supabase";
import type { DashboardMetrics } from "../types/metrics";
import { parseKpiMetricsV2, type KpiMetricsV2 } from "../types/kpiMetrics";
import { parseRealtimeMetrics, type RealtimeMetrics } from "../types/realtimeMetrics";
import { parseOpsMetrics, type OpsMetrics } from "../types/opsMetrics";
import {
  parseDailyExportRows,
  parseHourlyExportRows,
  parseRestaurantExportRows,
  type DailyExportRow,
  type HourlyExportRow,
  type RestaurantExportRow,
} from "../types/exportRangeMetrics";

function parseIntList(value: unknown, length: number): number[] {
  if (!Array.isArray(value)) return Array(length).fill(0);
  return value.map((e) =>
    typeof e === "number" ? Math.trunc(e) : Number.parseInt(String(e), 10) || 0,
  );
}

function parseDoubleList(value: unknown, length: number): number[] {
  if (!Array.isArray(value)) return Array(length).fill(0);
  return value.map((e) =>
    typeof e === "number" ? e : Number.parseFloat(String(e)) || 0,
  );
}

function parseCountMap(value: unknown): Record<string, number> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([k, v]) => [
      k,
      typeof v === "number" ? v : Number.parseInt(String(v), 10) || 0,
    ]),
  );
}

export function parseMetricsMap(map: Record<string, unknown>): DashboardMetrics {
  const topReporters: [string, number][] = [];
  const reportersRaw = map.top_reporters;
  if (Array.isArray(reportersRaw)) {
    for (const item of reportersRaw) {
      if (Array.isArray(item) && item.length >= 2) {
        topReporters.push([
          String(item[0] ?? "익명"),
          typeof item[1] === "number"
            ? item[1]
            : Number.parseInt(String(item[1]), 10) || 0,
        ]);
      }
    }
  }

  return {
    dauToday: Number(map.dau_today ?? 0),
    mau: Number(map.mau ?? 0),
    dailyDau: parseIntList(map.daily_dau, 7),
    monthlyMau: parseIntList(map.monthly_mau, 6),
    todayReports: Number(map.today_reports ?? 0),
    weekReports: Number(map.week_reports ?? 0),
    bannerClickRate: Number(map.banner_click_rate ?? 0),
    dailyClickRates: parseDoubleList(map.daily_click_rates, 7),
    pushOpenRate: Number(map.push_open_rate ?? 0),
    dailyPushOpenRates: parseDoubleList(map.daily_push_open_rates, 7),
    topReporters,
    todayByRestaurant: parseCountMap(map.today_by_restaurant),
    weekByRestaurant: parseCountMap(map.week_by_restaurant),
    todayGifticonsAssigned: Number(map.today_gifticons_assigned ?? 0),
    dailyGifticonsAssigned: parseIntList(map.daily_gifticons_assigned, 7),
    monthGifticonsAssigned: Number(map.month_gifticons_assigned ?? 0),
  };
}

export async function fetchDashboardMetrics(): Promise<DashboardMetrics> {
  const { data, error } = await supabase.rpc("admin_dashboard_metrics");
  if (error) throw error;
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("admin_dashboard_metrics returned invalid data");
  }
  return parseMetricsMap(data as Record<string, unknown>);
}

export async function fetchKpiMetrics(): Promise<KpiMetricsV2> {
  const { data, error } = await supabase.rpc("admin_kpi_metrics");
  if (error) throw error;
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("admin_kpi_metrics returned invalid data");
  }
  return parseKpiMetricsV2(data as Record<string, unknown>);
}

export async function fetchRealtimeMetrics(): Promise<RealtimeMetrics> {
  const { data, error } = await supabase.rpc("admin_realtime_metrics");
  if (error) throw error;
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("admin_realtime_metrics returned invalid data");
  }
  return parseRealtimeMetrics(data as Record<string, unknown>);
}

export async function fetchOpsMetrics(): Promise<OpsMetrics> {
  const { data, error } = await supabase.rpc("admin_ops_metrics");
  if (error) throw error;
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("admin_ops_metrics returned invalid data");
  }
  return parseOpsMetrics(data as Record<string, unknown>);
}

export async function fetchDailyExportMetrics(
  startDate: string,
  endDate: string,
): Promise<DailyExportRow[]> {
  const { data, error } = await supabase.rpc("admin_export_daily_metrics", {
    p_start: startDate,
    p_end: endDate,
  });
  if (error) throw error;
  return parseDailyExportRows((data as unknown[]) ?? []);
}

export async function fetchHourlyExportMetrics(
  startDate: string,
  endDate: string,
): Promise<HourlyExportRow[]> {
  const { data, error } = await supabase.rpc("admin_export_hourly_metrics", {
    p_start: startDate,
    p_end: endDate,
  });
  if (error) throw error;
  return parseHourlyExportRows((data as unknown[]) ?? []);
}

export async function fetchRestaurantExportMetrics(
  startDate: string,
  endDate: string,
): Promise<RestaurantExportRow[]> {
  const { data, error } = await supabase.rpc(
    "admin_export_restaurant_metrics",
    { p_start: startDate, p_end: endDate },
  );
  if (error) throw error;
  return parseRestaurantExportRows((data as unknown[]) ?? []);
}

export function last7DayLabels(): string[] {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (6 - i));
    return `${d.getMonth() + 1}/${d.getDate()}`;
  });
}

export function lastNDayLabels(n: number): string[] {
  return Array.from({ length: n }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (n - 1 - i));
    return `${d.getMonth() + 1}/${d.getDate()}`;
  });
}

export function hourlyLabels(): string[] {
  return Array.from({ length: 24 }, (_, h) => `${h}시`);
}

export function thisMonthDayLabels(daysElapsed: number): string[] {
  const now = new Date();
  return Array.from({ length: daysElapsed }, (_, i) => `${now.getMonth() + 1}/${i + 1}`);
}

export const LUNCH_30MIN_LABELS = [
  "11:00",
  "11:30",
  "12:00",
  "12:30",
  "13:00",
  "13:30",
];

export function last8WeekLabels(): string[] {
  return Array.from({ length: 8 }, (_, i) => (i === 7 ? "이번 주" : `${7 - i}주 전`));
}

export function last6MonthLabels(): string[] {
  const now = new Date();
  return Array.from({ length: 6 }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1);
    return `${d.getMonth() + 1}월`;
  });
}

export function formatCount(n: number): string {
  return n.toLocaleString("ko-KR");
}

export function formatRate(rate: number): string {
  return Number.isInteger(rate) ? String(rate) : rate.toFixed(1);
}

/** 최근 N개월 "YYYY-M" 키 목록 (오래된 순) */
export function lastNMonthKeys(n: number): string[] {
  const now = new Date();
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - (n - 1 - i), 1);
    return `${d.getFullYear()}-${d.getMonth() + 1}`;
  });
}

export function lastNMonthLabels(n: number): string[] {
  const now = new Date();
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - (n - 1 - i), 1);
    return `${d.getMonth() + 1}월`;
  });
}

function monthKey(date: Date): string {
  return `${date.getFullYear()}-${date.getMonth() + 1}`;
}

/** 날짜 배열을 최근 N개월 구간으로 월별 카운트 */
export function monthlyCounts(dates: Date[], months: number): number[] {
  const keys = lastNMonthKeys(months);
  const counts = new Map(keys.map((k) => [k, 0]));
  for (const d of dates) {
    const key = monthKey(d);
    if (counts.has(key)) counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return keys.map((k) => counts.get(k) ?? 0);
}

/** 월별 값 배열을 누적합으로 변환 (구간 이전 값들도 baseline에 포함) */
export function cumulativeCounts(dates: Date[], months: number): number[] {
  const keys = lastNMonthKeys(months);
  const firstKeyDate = new Date(
    Number(keys[0].split("-")[0]),
    Number(keys[0].split("-")[1]) - 1,
    1,
  );
  const baseline = dates.filter((d) => d.getTime() < firstKeyDate.getTime()).length;
  const counts = monthlyCounts(dates, months);
  let running = baseline;
  return counts.map((c) => {
    running += c;
    return running;
  });
}

export function levelToLabel(level: number | null): string {
  switch (level) {
    case 1:
      return "여유로움";
    case 2:
      return "약간혼잡";
    case 3:
      return "자리없음";
    default:
      return "정보없음";
  }
}

export function displayReporterName(raw: string): string {
  if (!raw.includes("@") && raw.length < 30) return raw;
  if (raw.includes("@")) return raw.split("@")[0] ?? raw;
  return `유저 ${raw.slice(-4)}`;
}
