import { useCallback, useEffect, useState } from "react";
import { fetchGifticons } from "../lib/adminApi";
import type { Gifticon } from "../types/gifticon";

export function useGifticons(enabled: boolean) {
  const [gifticons, setGifticons] = useState<Gifticon[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setGifticons(await fetchGifticons());
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { gifticons, loading, error, reload };
}
