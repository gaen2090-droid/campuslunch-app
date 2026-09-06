import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../lib/errors";
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
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { applications, loading, error, reload };
}
