import { useCallback, useEffect, useState } from "react";
import { fetchTrustSignalsReport } from "../lib/adminTrustApi";
import { errorMessage } from "../lib/errors";
import type { TrustSignalsReport } from "../types/trustAbuse";

export function useTrustSignals(enabled: boolean) {
  const [report, setReport] = useState<TrustSignalsReport | null>(null);
  const [days, setDays] = useState(30);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(
    async (nextDays?: number) => {
      const d = nextDays ?? days;
      setLoading(true);
      setError(null);
      try {
        const data = await fetchTrustSignalsReport(d);
        setReport(data);
        if (nextDays != null) setDays(nextDays);
      } catch (e) {
        setError(errorMessage(e));
        setReport(null);
      } finally {
        setLoading(false);
      }
    },
    [days],
  );

  useEffect(() => {
    if (!enabled) return;
    void reload();
  }, [enabled]); // eslint-disable-line react-hooks/exhaustive-deps

  return { report, days, loading, error, reload, setDays };
}
