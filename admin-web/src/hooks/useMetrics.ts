import { useCallback, useEffect, useState } from "react";
import { fetchDashboardMetrics } from "../lib/metrics";
import type { DashboardMetrics } from "../types/metrics";

const REFRESH_MS = 60_000;

export function useMetrics(enabled: boolean) {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setError(null);
    try {
      const m = await fetchDashboardMetrics();
      setMetrics(m);
      setUpdatedAt(new Date());
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (!enabled) return;
    setLoading(true);
    reload();
    const id = window.setInterval(reload, REFRESH_MS);
    return () => window.clearInterval(id);
  }, [enabled, reload]);

  return { metrics, loading, error, updatedAt, reload };
}
