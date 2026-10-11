import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../lib/errors";
import { fetchAppVersionStats } from "../lib/adminAppVersionApi";
import type { AppVersionStat } from "../types/appVersion";

export function useAppVersions(enabled: boolean) {
  const [stats, setStats] = useState<AppVersionStat[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setStats(await fetchAppVersionStats());
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { stats, loading, error, reload };
}
