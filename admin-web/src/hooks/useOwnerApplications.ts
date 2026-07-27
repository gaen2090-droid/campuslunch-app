import { useCallback, useEffect, useState } from "react";
import { fetchOwnerApplications } from "../lib/adminApi";
import type { OwnerApplication } from "../types/ownerApplication";

export function useOwnerApplications(enabled: boolean) {
  const [applications, setApplications] = useState<OwnerApplication[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setApplications(await fetchOwnerApplications());
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { applications, loading, error, reload };
}
