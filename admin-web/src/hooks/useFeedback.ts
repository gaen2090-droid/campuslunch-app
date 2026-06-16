import { useCallback, useEffect, useState } from "react";
import { fetchFeedback } from "../lib/adminApi";
import type { AppFeedback } from "../types/feedback";

export function useFeedback(enabled: boolean) {
  const [feedback, setFeedback] = useState<AppFeedback[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setFeedback(await fetchFeedback());
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { feedback, loading, error, reload };
}
