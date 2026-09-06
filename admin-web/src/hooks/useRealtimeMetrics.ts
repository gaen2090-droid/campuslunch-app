import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../lib/errors";
import { fetchRealtimeMetrics } from "../lib/metrics";
import type { RealtimeMetrics } from "../types/realtimeMetrics";

const REFRESH_MS = 60_000;

export function useRealtimeMetrics(enabled: boolean) {
  const [metrics, setMetrics] = useState<RealtimeMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setError(null);
    try {
      setMetrics(await fetchRealtimeMetrics());
      setUpdatedAt(new Date());
    } catch (e) {
      setError(errorMessage(e));
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
