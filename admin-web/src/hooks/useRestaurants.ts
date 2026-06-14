import { useCallback, useEffect, useState } from "react";
import { fetchAdminRestaurants } from "../lib/adminApi";
import type { AdminRestaurant } from "../types/restaurant";

export function useRestaurants(enabled: boolean) {
  const [restaurants, setRestaurants] = useState<AdminRestaurant[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setError(null);
    try {
      setRestaurants(await fetchAdminRestaurants());
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
  }, [enabled, reload]);

  return { restaurants, loading, error, reload };
}
