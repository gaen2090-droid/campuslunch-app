import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../lib/errors";
import { fetchOpsMetrics } from "../lib/metrics";
import type { OpsMetrics } from "../types/opsMetrics";

export function useOpsMetrics(enabled: boolean) {
  const [metrics, setMetrics] = useState<OpsMetrics | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setMetrics(await fetchOpsMetrics());
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { metrics, loading, error, reload };
}
