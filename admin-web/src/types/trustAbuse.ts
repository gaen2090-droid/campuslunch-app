export interface TrustSignalsUserRow {
  userId: string;
  nickname: string;
  email: string;
  reportCount: number;
  sameStoreIntervalPairCount: number;
  sameStoreIntervalAvgMin: number | null;
  sameStoreIntervalMedianMin: number | null;
  sameStoreIntervalMinMin: number | null;
  sameStoreIntervalMaxMin: number | null;
  sameStoreIntervalsMin: number[];
  allReportIntervalPairCount: number;
  allReportIntervalAvgMin: number | null;
  allReportIntervalMedianMin: number | null;
  allReportIntervalsMin: number[];
  movePairCount: number;
  moveAvgM: number | null;
  moveMedianM: number | null;
  moveMinM: number | null;
  moveMaxM: number | null;
  moveMeters: number[];
  areaTransitionCount: number;
  areaTransitions: Array<{
    fromArea: string;
    toArea: string;
    gapMin: number;
  }>;
  peerAgreeCount: number;
  peerOverlapCount: number;
  deviceIds: string[];
  deviceSiblingUserCount: number;
  deviceSiblingUserIds: string[];
  deviceMaxAccountsOnShared: number;
  attemptSuccess: number;
  attemptFail: number;
  failReasons: Record<string, number>;
  dwellMsTotal: number;
  dwellMsByScreen: Record<string, number>;
  detailViewN: number;
  mapClickN: number;
  searchClickN: number;
  bannerClickN: number;
  appSessionN: number;
  nonReportEventN: number;
  reportsInStampHours: number;
  reportsOutStampHours: number;
}

export interface TrustSignalsReport {
  days: number;
  since: string | null;
  users: TrustSignalsUserRow[];
  fields: string[];
}

export interface TrustSignalsUserDetail {
  days: number;
  since: string | null;
  summary: TrustSignalsUserRow | null;
  recentReports: Array<{
    id: string;
    restaurantId: string;
    restaurantName: string;
    area: string;
    level: string;
    lat: number | null;
    lng: number | null;
    deviceInstallId: string | null;
    appSessionId: string | null;
    createdAt: string;
  }>;
  recentAttempts: Array<{
    outcome: string;
    failReason: string | null;
    restaurantId: string | null;
    deviceInstallId: string | null;
    createdAt: string;
  }>;
}

function numOrNull(v: unknown): number | null {
  if (v == null || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function numArr(v: unknown): number[] {
  if (!Array.isArray(v)) return [];
  return v.map((x) => Number(x)).filter((n) => Number.isFinite(n));
}

function strArr(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.map((x) => String(x)).filter(Boolean);
}

function recordNum(v: unknown): Record<string, number> {
  if (!v || typeof v !== "object" || Array.isArray(v)) return {};
  const out: Record<string, number> = {};
  for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
    const n = Number(val);
    if (Number.isFinite(n)) out[k] = n;
  }
  return out;
}

export function parseTrustSignalsUser(raw: unknown): TrustSignalsUserRow | null {
  if (!raw || typeof raw !== "object") return null;
  const u = raw as Record<string, unknown>;
  const userId = String(u.user_id ?? "");
  if (!userId) return null;

  const transitionsRaw = Array.isArray(u.area_transitions)
    ? u.area_transitions
    : [];
  const areaTransitions = transitionsRaw
    .filter((t): t is Record<string, unknown> => !!t && typeof t === "object")
    .map((t) => ({
      fromArea: String(t.from_area ?? ""),
      toArea: String(t.to_area ?? ""),
      gapMin: Number(t.gap_min ?? 0) || 0,
    }));

  return {
    userId,
    nickname: String(u.nickname ?? ""),
    email: String(u.email ?? ""),
    reportCount: Number(u.report_count ?? 0) || 0,
    sameStoreIntervalPairCount:
      Number(u.same_store_interval_pair_count ?? 0) || 0,
    sameStoreIntervalAvgMin: numOrNull(u.same_store_interval_avg_min),
    sameStoreIntervalMedianMin: numOrNull(u.same_store_interval_median_min),
    sameStoreIntervalMinMin: numOrNull(u.same_store_interval_min_min),
    sameStoreIntervalMaxMin: numOrNull(u.same_store_interval_max_min),
    sameStoreIntervalsMin: numArr(u.same_store_intervals_min),
    allReportIntervalPairCount:
      Number(u.all_report_interval_pair_count ?? 0) || 0,
    allReportIntervalAvgMin: numOrNull(u.all_report_interval_avg_min),
    allReportIntervalMedianMin: numOrNull(u.all_report_interval_median_min),
    allReportIntervalsMin: numArr(u.all_report_intervals_min),
    movePairCount: Number(u.move_pair_count ?? 0) || 0,
    moveAvgM: numOrNull(u.move_avg_m),
    moveMedianM: numOrNull(u.move_median_m),
    moveMinM: numOrNull(u.move_min_m),
    moveMaxM: numOrNull(u.move_max_m),
    moveMeters: numArr(u.move_meters),
    areaTransitionCount: Number(u.area_transition_count ?? 0) || 0,
    areaTransitions,
    peerAgreeCount: Number(u.peer_agree_count ?? 0) || 0,
    peerOverlapCount: Number(u.peer_overlap_count ?? 0) || 0,
    deviceIds: strArr(u.device_ids),
    deviceSiblingUserCount: Number(u.device_sibling_user_count ?? 0) || 0,
    deviceSiblingUserIds: strArr(u.device_sibling_user_ids),
    deviceMaxAccountsOnShared:
      Number(u.device_max_accounts_on_shared ?? 1) || 1,
    attemptSuccess: Number(u.attempt_success ?? 0) || 0,
    attemptFail: Number(u.attempt_fail ?? 0) || 0,
    failReasons: recordNum(u.fail_reasons),
    dwellMsTotal: Number(u.dwell_ms_total ?? 0) || 0,
    dwellMsByScreen: recordNum(u.dwell_ms_by_screen),
    detailViewN: Number(u.detail_view_n ?? 0) || 0,
    mapClickN: Number(u.map_click_n ?? 0) || 0,
    searchClickN: Number(u.search_click_n ?? 0) || 0,
    bannerClickN: Number(u.banner_click_n ?? 0) || 0,
    appSessionN: Number(u.app_session_n ?? 0) || 0,
    nonReportEventN: Number(u.non_report_event_n ?? 0) || 0,
    reportsInStampHours: Number(u.reports_in_stamp_hours ?? 0) || 0,
    reportsOutStampHours: Number(u.reports_out_stamp_hours ?? 0) || 0,
  };
}

export function parseTrustSignalsReport(raw: unknown): TrustSignalsReport {
  const map =
    raw && typeof raw === "object" && !Array.isArray(raw)
      ? (raw as Record<string, unknown>)
      : {};
  const usersRaw = Array.isArray(map.users) ? map.users : [];
  const users = usersRaw
    .map(parseTrustSignalsUser)
    .filter((u): u is TrustSignalsUserRow => !!u);

  return {
    days: Number(map.days ?? 30) || 30,
    since: map.since != null ? String(map.since) : null,
    users,
    fields: Array.isArray(map.fields)
      ? map.fields.map((f) => String(f))
      : [],
  };
}

export function parseTrustSignalsUserDetail(
  raw: unknown,
): TrustSignalsUserDetail {
  const map =
    raw && typeof raw === "object" && !Array.isArray(raw)
      ? (raw as Record<string, unknown>)
      : {};
  const reportsRaw = Array.isArray(map.recent_reports)
    ? map.recent_reports
    : [];
  const attemptsRaw = Array.isArray(map.recent_attempts)
    ? map.recent_attempts
    : [];

  return {
    days: Number(map.days ?? 30) || 30,
    since: map.since != null ? String(map.since) : null,
    summary: parseTrustSignalsUser(map.summary),
    recentReports: reportsRaw
      .filter((r): r is Record<string, unknown> => !!r && typeof r === "object")
      .map((r) => ({
        id: String(r.id ?? ""),
        restaurantId: String(r.restaurant_id ?? ""),
        restaurantName: String(r.restaurant_name ?? ""),
        area: String(r.area ?? ""),
        level: String(r.level ?? ""),
        lat: numOrNull(r.lat),
        lng: numOrNull(r.lng),
        deviceInstallId:
          r.device_install_id != null ? String(r.device_install_id) : null,
        appSessionId:
          r.app_session_id != null ? String(r.app_session_id) : null,
        createdAt: String(r.created_at ?? ""),
      })),
    recentAttempts: attemptsRaw
      .filter((r): r is Record<string, unknown> => !!r && typeof r === "object")
      .map((r) => ({
        outcome: String(r.outcome ?? ""),
        failReason: r.fail_reason != null ? String(r.fail_reason) : null,
        restaurantId:
          r.restaurant_id != null ? String(r.restaurant_id) : null,
        deviceInstallId:
          r.device_install_id != null ? String(r.device_install_id) : null,
        createdAt: String(r.created_at ?? ""),
      })),
  };
}

export function fmtMin(n: number | null | undefined): string {
  if (n == null || !Number.isFinite(n)) return "-";
  return `${n}분`;
}

export function fmtMeters(n: number | null | undefined): string {
  if (n == null || !Number.isFinite(n)) return "-";
  return `${n}m`;
}

export function fmtMs(n: number | null | undefined): string {
  if (n == null || !Number.isFinite(n) || n <= 0) return "-";
  if (n < 60000) return `${Math.round(n / 1000)}초`;
  return `${(n / 60000).toFixed(1)}분`;
}
