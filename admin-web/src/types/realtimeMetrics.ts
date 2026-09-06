export interface RestaurantReportRow {
  restaurantId: string;
  name: string;
  count: number;
}

export interface RestaurantViewRow {
  restaurantId: string;
  name: string;
  count: number;
}

export interface CoverageRestaurantRow {
  restaurantId: string;
  name: string;
  lastReportAt: Date | null;
}

export interface Top5RestaurantRow {
  restaurantId: string;
  name: string;
  todayReports: number;
  weekReports: number;
  currentLevel: number | null;
  lastReportAt: Date | null;
  todayDetailViews: number;
}

export interface RealtimeMetrics {
  activeToday: number;
  activeYesterday: number;
  hourlyActive: number[];
  dailyActive7d: number[];
  dailyActive30d: number[];
  newUsersToday: number;
  existingUsersToday: number;

  lunchUsersToday: number;
  lunchUsersYesterday: number;
  lunch30min: number[];
  lunchDaily7d: number[];
  lunchDaily30d: number[];

  newSignupsToday: number;
  newSignupsYesterday: number;
  dailySignups7d: number[];
  dailySignups30d: number[];
  totalSignups: number;

  reportsToday: number;
  reportsYesterday: number;
  reportsWeek: number;
  reportsTotal: number;
  hourlyReports: number[];
  dailyReports7d: number[];
  dailyReports30d: number[];
  reportsUserToday: number;
  reportsOwnerToday: number;
  reportsByLevel: Record<string, number>;
  topRestaurantsByReports: RestaurantReportRow[];

  participantsToday: number;
  participantsYesterday: number;
  dailyParticipants7d: number[];
  dailyParticipants30d: number[];
  avgReportsPerParticipant: number;
  participantDist1: number;
  participantDist2: number;
  participantDist3plus: number;
  repeatReporterRate: number;

  coverageRate: number;
  coverageRestaurantsWithReport: number;
  coverageTotalRestaurants: number;
  coveredRestaurants: CoverageRestaurantRow[];
  uncoveredRestaurants: CoverageRestaurantRow[];

  detailViewsToday: number;
  detailViewsYesterday: number;
  hourlyDetailViews: number[];
  dailyDetailViews7d: number[];
  dailyDetailViews30d: number[];
  topRestaurantsByViews: RestaurantViewRow[];

  top5RestaurantsByReports: Top5RestaurantRow[];
}

function parseIntArray(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => (typeof v === "number" ? v : Number(v) || 0));
}

function parseRestaurantRows(value: unknown): RestaurantReportRow[] {
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

function parseCoverageRows(value: unknown): CoverageRestaurantRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = raw as Record<string, unknown>;
    return {
      restaurantId: String(row.restaurant_id ?? ""),
      name: String(row.name ?? ""),
      lastReportAt: row.last_report_at ? new Date(String(row.last_report_at)) : null,
    };
  });
}

function parseTop5Rows(value: unknown): Top5RestaurantRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = raw as Record<string, unknown>;
    return {
      restaurantId: String(row.restaurant_id ?? ""),
      name: String(row.name ?? ""),
      todayReports: Number(row.today_reports ?? 0),
      weekReports: Number(row.week_reports ?? 0),
      currentLevel: row.current_level != null ? Number(row.current_level) : null,
      lastReportAt: row.last_report_at ? new Date(String(row.last_report_at)) : null,
      todayDetailViews: Number(row.today_detail_views ?? 0),
    };
  });
}

function parseCountRecord(value: unknown): Record<string, number> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, Number(v) || 0]),
  );
}

export function parseRealtimeMetrics(map: Record<string, unknown>): RealtimeMetrics {
  return {
    activeToday: Number(map.active_today ?? 0),
    activeYesterday: Number(map.active_yesterday ?? 0),
    hourlyActive: parseIntArray(map.hourly_active),
    dailyActive7d: parseIntArray(map.daily_active_7d),
    dailyActive30d: parseIntArray(map.daily_active_30d),
    newUsersToday: Number(map.new_users_today ?? 0),
    existingUsersToday: Number(map.existing_users_today ?? 0),

    lunchUsersToday: Number(map.lunch_users_today ?? 0),
    lunchUsersYesterday: Number(map.lunch_users_yesterday ?? 0),
    lunch30min: parseIntArray(map.lunch_30min),
    lunchDaily7d: parseIntArray(map.lunch_daily_7d),
    lunchDaily30d: parseIntArray(map.lunch_daily_30d),

    newSignupsToday: Number(map.new_signups_today ?? 0),
    newSignupsYesterday: Number(map.new_signups_yesterday ?? 0),
    dailySignups7d: parseIntArray(map.daily_signups_7d),
    dailySignups30d: parseIntArray(map.daily_signups_30d),
    totalSignups: Number(map.total_signups ?? 0),

    reportsToday: Number(map.reports_today ?? 0),
    reportsYesterday: Number(map.reports_yesterday ?? 0),
    reportsWeek: Number(map.reports_week ?? 0),
    reportsTotal: Number(map.reports_total ?? 0),
    hourlyReports: parseIntArray(map.hourly_reports),
    dailyReports7d: parseIntArray(map.daily_reports_7d),
    dailyReports30d: parseIntArray(map.daily_reports_30d),
    reportsUserToday: Number(map.reports_user_today ?? 0),
    reportsOwnerToday: Number(map.reports_owner_today ?? 0),
    reportsByLevel: parseCountRecord(map.reports_by_level),
    topRestaurantsByReports: parseRestaurantRows(map.top_restaurants_by_reports),

    participantsToday: Number(map.participants_today ?? 0),
    participantsYesterday: Number(map.participants_yesterday ?? 0),
    dailyParticipants7d: parseIntArray(map.daily_participants_7d),
    dailyParticipants30d: parseIntArray(map.daily_participants_30d),
    avgReportsPerParticipant: Number(map.avg_reports_per_participant ?? 0),
    participantDist1: Number(map.participant_dist_1 ?? 0),
    participantDist2: Number(map.participant_dist_2 ?? 0),
    participantDist3plus: Number(map.participant_dist_3plus ?? 0),
    repeatReporterRate: Number(map.repeat_reporter_rate ?? 0),

    coverageRate: Number(map.coverage_rate ?? 0),
    coverageRestaurantsWithReport: Number(map.coverage_restaurants_with_report ?? 0),
    coverageTotalRestaurants: Number(map.coverage_total_restaurants ?? 0),
    coveredRestaurants: parseCoverageRows(map.covered_restaurants),
    uncoveredRestaurants: parseCoverageRows(map.uncovered_restaurants),

    detailViewsToday: Number(map.detail_views_today ?? 0),
    detailViewsYesterday: Number(map.detail_views_yesterday ?? 0),
    hourlyDetailViews: parseIntArray(map.hourly_detail_views),
    dailyDetailViews7d: parseIntArray(map.daily_detail_views_7d),
    dailyDetailViews30d: parseIntArray(map.daily_detail_views_30d),
    topRestaurantsByViews: parseRestaurantRows(map.top_restaurants_by_views),

    top5RestaurantsByReports: parseTop5Rows(map.top_restaurants_by_reports_full),
  };
}
