import { supabase } from "./supabase";
import {
  parseTrustSignalsReport,
  parseTrustSignalsUserDetail,
  type TrustSignalsReport,
  type TrustSignalsUserDetail,
} from "../types/trustAbuse";

export async function fetchTrustSignalsReport(
  days = 30,
): Promise<TrustSignalsReport> {
  const { data, error } = await supabase.rpc("admin_trust_signals_report", {
    p_days: days,
  });
  if (error) throw error;
  return parseTrustSignalsReport(data);
}

export async function fetchTrustSignalsUserDetail(
  userId: string,
  days = 30,
): Promise<TrustSignalsUserDetail> {
  const { data, error } = await supabase.rpc("admin_trust_signals_user", {
    p_user_id: userId,
    p_days: days,
  });
  if (error) throw error;
  return parseTrustSignalsUserDetail(data);
}

