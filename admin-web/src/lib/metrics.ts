import { supabase } from "./supabase";
import type { DashboardMetrics } from "../types/metrics";

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

export function last7DayLabels(): string[] {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (6 - i));
    return `${d.getMonth() + 1}/${d.getDate()}`;
  });
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

export function displayReporterName(raw: string): string {
  if (!raw.includes("@") && raw.length < 30) return raw;
  if (raw.includes("@")) return raw.split("@")[0] ?? raw;
  return `유저 ${raw.slice(-4)}`;
}
