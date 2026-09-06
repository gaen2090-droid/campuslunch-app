import { useCallback, useEffect, useState } from "react";
import { fetchKpiTargets, upsertKpiTarget } from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import type { KpiMetricKey, KpiTarget } from "../types/kpiTarget";

export function useKpiTargets(enabled: boolean) {
  const [targets, setTargets] = useState<KpiTarget[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setTargets(await fetchKpiTargets());
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  const saveTarget = useCallback(
    async (metricKey: KpiMetricKey, periodMonth: Date, targetValue: number) => {
      await upsertKpiTarget(metricKey, periodMonth, targetValue);
      await reload();
    },
    [reload],
  );

  return { targets, loading, error, reload, saveTarget };
}
