export interface DailyExportRow {
  day: string;
  activeUsers: number;
  lunchUsers: number;
  newSignups: number;
  reports: number;
  reportParticipants: number;
  detailViews: number;
  bannerImpressions: number;
  bannerClicks: number;
  pushDelivered: number;
  pushClicks: number;
}

export interface HourlyExportRow {
  day: string;
  hour: number;
  activeUsers: number;
  reports: number;
  detailViews: number;
}

export interface RestaurantExportRow {
  restaurantId: string;
  name: string;
  area: string;
  category: string;
  ownerRegistered: boolean;
  reportsRelaxed: number;
  reportsModerate: number;
  reportsFull: number;
  reportsTotal: number;
  reportParticipants: number;
  detailViews: number;
}

function num(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

export function parseDailyExportRows(rows: unknown[]): DailyExportRow[] {
  return rows.map((row) => {
    const r = row as Record<string, unknown>;
    return {
      day: String(r.day ?? ""),
      activeUsers: num(r.active_users),
      lunchUsers: num(r.lunch_users),
      newSignups: num(r.new_signups),
      reports: num(r.reports),
      reportParticipants: num(r.report_participants),
      detailViews: num(r.detail_views),
      bannerImpressions: num(r.banner_impressions),
      bannerClicks: num(r.banner_clicks),
      pushDelivered: num(r.push_delivered),
      pushClicks: num(r.push_clicks),
    };
  });
}

export function parseHourlyExportRows(rows: unknown[]): HourlyExportRow[] {
  return rows.map((row) => {
    const r = row as Record<string, unknown>;
    return {
      day: String(r.day ?? ""),
      hour: num(r.hour),
      activeUsers: num(r.active_users),
      reports: num(r.reports),
      detailViews: num(r.detail_views),
    };
  });
}

export function parseRestaurantExportRows(rows: unknown[]): RestaurantExportRow[] {
  return rows.map((row) => {
    const r = row as Record<string, unknown>;
    return {
      restaurantId: String(r.restaurant_id ?? ""),
      name: String(r.name ?? ""),
      area: String(r.area ?? ""),
      category: String(r.category ?? ""),
      ownerRegistered: Boolean(r.owner_registered),
      reportsRelaxed: num(r.reports_relaxed),
      reportsModerate: num(r.reports_moderate),
      reportsFull: num(r.reports_full),
      reportsTotal: num(r.reports_total),
      reportParticipants: num(r.report_participants),
      detailViews: num(r.detail_views),
    };
  });
}
