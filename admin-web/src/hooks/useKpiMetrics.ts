import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../lib/errors";
import { fetchKpiMetrics } from "../lib/metrics";
import type { KpiMetricsV2 } from "../types/kpiMetrics";

export function useKpiMetrics(enabled: boolean) {
  const [kpiMetrics, setKpiMetrics] = useState<KpiMetricsV2 | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setKpiMetrics(await fetchKpiMetrics());
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { kpiMetrics, loading, error, reload };
}
