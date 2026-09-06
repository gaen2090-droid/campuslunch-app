export interface KpiRestaurantRow {
  restaurantId: string;
  name: string;
  count: number;
}

export interface KpiMetricsV2 {
  // 참고용 누적 스냅샷
  totalReports: number;
  totalPosts: number;
  monthlyReports: number[];
  monthlyPosts: number[];
  totalByRestaurant: Record<string, number>;

  // 1. 신규 가입자
  newUsersThisMonth: number;
  newUsersPrevMonthSamePoint: number;
  newUsersDailyThisMonth: number[];
  totalSignups: number;

  // 2. 점심시간 일평균 사용자
  lunchDailyThisMonth: number[];
  lunchAvgThisMonth: number;
  lunchAvg7d: number;
  lunchByWeekday: Record<string, number>;
  lunch30minAvg: number[];

  // 3. WAU
  wauCurrent: number;
  wauPrevWeek: number;
  wau8w: number[];
  wauNewRatio: number;
  wauExistingRatio: number;

  // 4. 제보 건수
  reportsThisMonth: number;
  reportsPrevMonthSamePoint: number;
  reportsDailyThisMonth: number[];
  reportsUserMonth: number;
  reportsOwnerMonth: number;
  reportsHourlyMonth: Record<string, number>;
  topRestaurantsMonth: KpiRestaurantRow[];

  // 5. 일평균 제보 참여자
  participantsDailyThisMonth: number[];
  participantsAvgThisMonth: number;
  participantsAvg7d: number;
  avgReportsPerParticipantMonth: number;
  repeatRate7d: number;

  // 6. 실시간 혼잡도 커버리지
  coverageDailyThisMonth: number[];
  coverageAvgThisMonth: number;
  coverageAvg7d: number;
  coverageCurrent: number;
  coverageTotalRestaurants: number;
  sparseRestaurants: { restaurantId: string; name: string; reportCount: number }[];

  // 보조: 활성 사용자 추이 (DAU/WAU/MAU)
  activeToday: number;
  activeYesterday: number;
  activeDaily7d: number[];
  activeDaily30d: number[];
  activeAvg7d: number;
  activeAvg30d: number;
  activeMonthly6m: number[];
  activeMonthCurrent: number;
  activeMonthPrev: number;
}

function parseIntArray(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => (typeof v === "number" ? v : Number(v) || 0));
}

function parseCountRecord(value: unknown): Record<string, number> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, Number(v) || 0]),
  );
}

function parseRestaurantRows(value: unknown): KpiRestaurantRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = raw as Record<string, unknown>;
    return {
      restaurantId: String(row.restaurant_id ?? ""),
      name: String(row.name ?? ""),
      count: Number(row.count ?? 0),
    };
  });
}

export function parseKpiMetricsV2(map: Record<string, unknown>): KpiMetricsV2 {
  return {
    totalReports: Number(map.total_reports ?? 0),
    totalPosts: Number(map.total_posts ?? 0),
    monthlyReports: parseIntArray(map.monthly_reports),
    monthlyPosts: parseIntArray(map.monthly_posts),
    totalByRestaurant: parseCountRecord(map.total_by_restaurant),

    newUsersThisMonth: Number(map.new_users_this_month ?? 0),
    newUsersPrevMonthSamePoint: Number(map.new_users_prev_month_same_point ?? 0),
    newUsersDailyThisMonth: parseIntArray(map.new_users_daily_this_month),
    totalSignups: Number(map.total_signups ?? 0),

    lunchDailyThisMonth: parseIntArray(map.lunch_daily_this_month),
    lunchAvgThisMonth: Number(map.lunch_avg_this_month ?? 0),
    lunchAvg7d: Number(map.lunch_avg_7d ?? 0),
    lunchByWeekday: parseCountRecord(map.lunch_by_weekday),
    lunch30minAvg: parseIntArray(map.lunch_30min_avg),

    wauCurrent: Number(map.wau_current ?? 0),
    wauPrevWeek: Number(map.wau_prev_week ?? 0),
    wau8w: parseIntArray(map.wau_8w),
    wauNewRatio: Number(map.wau_new_ratio ?? 0),
    wauExistingRatio: Number(map.wau_existing_ratio ?? 0),

    reportsThisMonth: Number(map.reports_this_month ?? 0),
    reportsPrevMonthSamePoint: Number(map.reports_prev_month_same_point ?? 0),
    reportsDailyThisMonth: parseIntArray(map.reports_daily_this_month),
    reportsUserMonth: Number(map.reports_user_month ?? 0),
    reportsOwnerMonth: Number(map.reports_owner_month ?? 0),
    reportsHourlyMonth: parseCountRecord(map.reports_hourly_month),
    topRestaurantsMonth: parseRestaurantRows(map.top_restaurants_month),

    participantsDailyThisMonth: parseIntArray(map.participants_daily_this_month),
    participantsAvgThisMonth: Number(map.participants_avg_this_month ?? 0),
    participantsAvg7d: Number(map.participants_avg_7d ?? 0),
    avgReportsPerParticipantMonth: Number(map.avg_reports_per_participant_month ?? 0),
    repeatRate7d: Number(map.repeat_rate_7d ?? 0),

    coverageDailyThisMonth: parseIntArray(map.coverage_daily_this_month),
    coverageAvgThisMonth: Number(map.coverage_avg_this_month ?? 0),
    coverageAvg7d: Number(map.coverage_avg_7d ?? 0),
    coverageCurrent: Number(map.coverage_current ?? 0),
    coverageTotalRestaurants: Number(map.coverage_total_restaurants ?? 0),
    sparseRestaurants: Array.isArray(map.sparse_restaurants)
      ? (map.sparse_restaurants as Record<string, unknown>[]).map((raw) => ({
          restaurantId: String(raw.restaurant_id ?? ""),
          name: String(raw.name ?? ""),
          reportCount: Number(raw.report_count ?? 0),
        }))
      : [],

    activeToday: Number(map.active_today ?? 0),
    activeYesterday: Number(map.active_yesterday ?? 0),
    activeDaily7d: parseIntArray(map.active_daily_7d),
    activeDaily30d: parseIntArray(map.active_daily_30d),
    activeAvg7d: Number(map.active_avg_7d ?? 0),
    activeAvg30d: Number(map.active_avg_30d ?? 0),
    activeMonthly6m: parseIntArray(map.active_monthly_6m),
    activeMonthCurrent: Number(map.active_month_current ?? 0),
    activeMonthPrev: Number(map.active_month_prev ?? 0),
  };
}
