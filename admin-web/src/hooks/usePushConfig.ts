import { useCallback, useEffect, useState } from "react";
import { fetchPushNotificationConfig } from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import {
  DEFAULT_PUSH_CONFIG,
  type PushNotificationConfig,
} from "../types/pushConfig";

export function usePushConfig(enabled: boolean) {
  const [config, setConfig] = useState<PushNotificationConfig | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setConfig(await fetchPushNotificationConfig());
    } catch (err) {
      setError(errorMessage(err));
      setConfig(DEFAULT_PUSH_CONFIG);
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    void reload();
  }, [reload]);

  return { config, loading, error, reload, setConfig };
}
