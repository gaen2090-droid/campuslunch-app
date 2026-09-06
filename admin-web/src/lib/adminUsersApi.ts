import { supabase } from "./supabase";
import { parseAdminUser, type AdminUser } from "../types/user";

export async function fetchAdminUsers(): Promise<AdminUser[]> {
  const { data, error } = await supabase.rpc("admin_list_users");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) =>
    parseAdminUser(row as Record<string, unknown>),
  );
}

export async function purgeAdminUser(email: string): Promise<string> {
  const { data, error } = await supabase.rpc("admin_purge_user_by_email", {
    p_email: email.trim(),
  });
  if (error) throw error;
  const result = (data ?? {}) as Record<string, unknown>;
  if (result.ok !== true) {
    throw new Error(String(result.message ?? "삭제에 실패했어요."));
  }
  return String(result.message ?? "삭제 완료");
}

export async function purgeAdminUserById(userId: string): Promise<string> {
  const { data, error } = await supabase.rpc("admin_purge_user_by_id", {
    p_user_id: userId,
  });
  if (error) throw error;
  const result = (data ?? {}) as Record<string, unknown>;
  if (result.ok !== true) {
    throw new Error(String(result.message ?? "삭제에 실패했어요."));
  }
  return String(result.message ?? "삭제 완료");
}

/** p_days가 0이면 정지 해제 */
export async function setCommunitySuspension(
  userId: string,
  days: number,
  reason: string,
): Promise<void> {
  const { data, error } = await supabase.rpc("admin_set_community_suspension", {
    p_user_id: userId,
    p_days: days,
    p_reason: reason || null,
  });
  if (error) throw error;
  const result = (data ?? {}) as Record<string, unknown>;
  if (result.ok !== true) {
    throw new Error(String(result.message ?? "처리에 실패했어요."));
  }
}

/** p_days가 0이면 정지 해제 */
export async function setReportSuspension(
  userId: string,
  days: number,
  reason: string,
): Promise<void> {
  const { data, error } = await supabase.rpc("admin_set_report_suspension", {
    p_user_id: userId,
    p_days: days,
    p_reason: reason || null,
  });
  if (error) throw error;
  const result = (data ?? {}) as Record<string, unknown>;
  if (result.ok !== true) {
    throw new Error(String(result.message ?? "처리에 실패했어요."));
  }
}

