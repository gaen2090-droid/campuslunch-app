import { useCallback, useEffect, useState } from "react";
import { fetchAdminUsers } from "../lib/adminApi";
import type { AdminUser } from "../types/user";

export function useUsers(enabled: boolean) {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      setUsers(await fetchAdminUsers());
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    void reload();
  }, [reload]);

  return { users, loading, error, reload };
}
