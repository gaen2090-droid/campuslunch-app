import { supabase } from "./supabase";
import { parseKpiTarget, type KpiMetricKey, type KpiTarget } from "../types/kpiTarget";

export async function fetchKpiTargets(): Promise<KpiTarget[]> {
  const { data, error } = await supabase.rpc("admin_list_kpi_targets");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseKpiTarget(row as Record<string, unknown>));
}

export async function upsertKpiTarget(
  metricKey: KpiMetricKey,
  periodMonth: Date,
  targetValue: number,
): Promise<void> {
  const monthStr = `${periodMonth.getFullYear()}-${String(periodMonth.getMonth() + 1).padStart(2, "0")}-01`;
  const { error } = await supabase.rpc("admin_upsert_kpi_target", {
    p_metric_key: metricKey,
    p_period_month: monthStr,
    p_target_value: targetValue,
  });
  if (error) throw error;
}

