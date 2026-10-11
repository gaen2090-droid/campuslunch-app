import { supabase } from "./supabase";
import { parseAppVersionStat, type AppVersionStat } from "../types/appVersion";

/** 가입자 전체의 (플랫폼, 앱 버전)별 사용자 수 */
export async function fetchAppVersionStats(): Promise<AppVersionStat[]> {
  const { data, error } = await supabase.rpc("admin_app_version_stats");
  if (error) throw error;
  return ((data as Record<string, unknown>[]) ?? []).map(parseAppVersionStat);
}
