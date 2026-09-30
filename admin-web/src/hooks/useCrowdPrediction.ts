import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../lib/errors";
import {
  fetchCrowdPredictionDailyCounts,
  fetchCrowdPredictionLunch,
} from "../lib/adminCrowdPredictionApi";
import type {
  CrowdPredictionDailyCount,
  CrowdPredictionRestaurant,
} from "../types/crowdPrediction";

export function useCrowdPrediction(enabled: boolean) {
  const [restaurants, setRestaurants] = useState<CrowdPredictionRestaurant[]>(
    [],
  );
  const [dailyCounts, setDailyCounts] = useState<CrowdPredictionDailyCount[]>(
    [],
  );
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const [restaurantsResult, dailyCountsResult] = await Promise.all([
        fetchCrowdPredictionLunch(),
        fetchCrowdPredictionDailyCounts(7),
      ]);
      setRestaurants(restaurantsResult);
      setDailyCounts(dailyCountsResult);
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) reload();
  }, [enabled, reload]);

  return { restaurants, dailyCounts, loading, error, reload };
}
