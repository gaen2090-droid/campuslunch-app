import { supabase } from "./supabase";
import {
  groupByRestaurant,
  parseDailyCounts,
  type CrowdPredictionDailyCount,
  type CrowdPredictionRestaurant,
} from "../types/crowdPrediction";

/** 점심(12~13시, 평일, KST) 15분 단위 매장별 혼잡도 예측 조회 */
export async function fetchCrowdPredictionLunch(): Promise<
  CrowdPredictionRestaurant[]
> {
  // v2는 서버가 계산한 relax_probability 를 함께 준다. 아직 SQL이 적용되지 않았으면
  // 기존 RPC로 폴백하고, 확률은 같은 식으로 클라이언트에서 계산한다.
  const v2 = await supabase.rpc("admin_crowd_prediction_lunch_v2");
  if (!v2.error) return groupByRestaurant((v2.data as unknown[]) ?? []);

  const { data, error } = await supabase.rpc("admin_crowd_prediction_lunch");
  if (error) throw error;
  return groupByRestaurant((data as unknown[]) ?? []);
}

/** 최근 N일(기본 7일) 평일 점심 유효 제보 수 — 표본 추적(증가 속도 추정)용 */
export async function fetchCrowdPredictionDailyCounts(
  days = 7,
): Promise<CrowdPredictionDailyCount[]> {
  const { data, error } = await supabase.rpc(
    "admin_crowd_prediction_daily_counts",
    { p_days: days },
  );
  if (error) throw error;
  return parseDailyCounts((data as unknown[]) ?? []);
}
