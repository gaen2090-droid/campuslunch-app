import { supabase } from "./supabase";
import { errorMessage } from "./errors";
import type {
  AdminRestaurant,
  MenuItem,
  RecentCrowdReport,
  RestaurantFormData,
} from "../types/restaurant";

function parseDescription(raw: unknown): Record<string, unknown> | null {
  if (raw == null) return null;
  if (typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  if (typeof raw === "string" && raw.length > 0) {
    try {
      const decoded = JSON.parse(raw);
      if (decoded && typeof decoded === "object" && !Array.isArray(decoded)) {
        return decoded as Record<string, unknown>;
      }
    } catch {
      /* ignore */
    }
  }
  return null;
}

function crowdLevelToStatus(
  level: string,
  metadata?: Record<string, unknown>,
): string {
  const fromMeta = metadata?.status;
  if (typeof fromMeta === "string" && fromMeta.length > 0) return fromMeta;
  const map: Record<string, string> = {
    normal: "여유로움",
    full: "약간혼잡",
    closed: "영업안함",
  };
  return map[level] ?? "여유로움";
}

function parseMenu(raw: unknown): MenuItem[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((m) => {
      if (!m || typeof m !== "object") return null;
      const item = m as Record<string, unknown>;
      const name = String(item.name ?? "");
      const price =
        typeof item.price === "number"
          ? item.price
          : Number.parseInt(String(item.price ?? "0"), 10) || 0;
      return name ? { name, price } : null;
    })
    .filter((m): m is MenuItem => m != null);
}

function parseHours(extra: Record<string, unknown> | null): string {
  if (!extra) return "11:00 - 21:00";
  const h = extra.hours;
  if (typeof h === "string" && h.length > 0) return h;
  return "11:00 - 21:00";
}

function buildReportCounts(
  reports: Record<string, unknown>[],
  snapshot?: unknown,
): Record<string, number> {
  if (snapshot && typeof snapshot === "object" && !Array.isArray(snapshot)) {
    const out: Record<string, number> = {};
    for (const [k, v] of Object.entries(snapshot as Record<string, unknown>)) {
      out[k] = typeof v === "number" ? v : Number.parseInt(String(v), 10) || 0;
    }
    return out;
  }
  const counts: Record<string, number> = {};
  for (const r of reports) {
    const meta = (r.metadata as Record<string, unknown> | undefined) ?? {};
    const label = crowdLevelToStatus(String(r.level ?? "normal"), meta);
    if (label !== "영업안함") {
      counts[label] = (counts[label] ?? 0) + 1;
    }
  }
  return counts;
}

function mergeRestaurant(
  row: Record<string, unknown>,
  reports: Record<string, unknown>[],
  crowdStatus?: Record<string, unknown>,
): AdminRestaurant {
  const extra = parseDescription(row.description);
  const id = String(row.id);

  let status = "제보필요";
  let updated = 0;
  let hasCrowdUpdate = false;
  let crowdBaseSource = "";
  let crowdConfidence = "";

  if (crowdStatus) {
    const meta = (crowdStatus.metadata as Record<string, unknown> | undefined) ?? {};
    status = crowdLevelToStatus(String(crowdStatus.level ?? "normal"), meta);
    crowdBaseSource = String(crowdStatus.base_source ?? "");
    crowdConfidence = String(crowdStatus.confidence ?? "");
    const rawUpdated = crowdStatus.updated_at as string | undefined;
    if (rawUpdated) {
      const dt = new Date(rawUpdated);
      updated = Math.max(
        0,
        Math.floor((Date.now() - dt.getTime()) / 60_000),
      );
      hasCrowdUpdate = true;
    }
  } else if (reports.length > 0) {
    const latest = reports.reduce((best, r) => {
      const t = new Date(String(r.created_at)).getTime();
      return t > best ? t : best;
    }, 0);
    updated = Math.max(0, Math.floor((Date.now() - latest) / 60_000));
    hasCrowdUpdate = true;
    const last = reports[0];
    const meta = (last.metadata as Record<string, unknown> | undefined) ?? {};
    status = crowdLevelToStatus(String(last.level ?? "normal"), meta);
  }

  const reportCounts = buildReportCounts(reports, extra?.reports_snapshot);

  return {
    id,
    linkNo: Number(row.link_no ?? 0) || 0,
    name: String(row.name ?? ""),
    category: String(row.category ?? ""),
    area: String(row.area ?? ""),
    address: String(row.address ?? row.area ?? ""),
    status,
    hours: parseHours(extra),
    imageUrl: String(row.image_url ?? ""),
    latitude: Number(row.latitude ?? 0),
    longitude: Number(row.longitude ?? 0),
    reports: reportCounts,
    menu: parseMenu(extra?.menu),
    ownerId: row.owner_id ? String(row.owner_id) : null,
    manualRank:
      typeof extra?.manual_rank === "number"
        ? extra.manual_rank
        : Number.parseInt(String(extra?.manual_rank ?? "0"), 10) || 0,
    popularityScore: 0,
    crowdBaseSource,
    crowdConfidence,
    hasCrowdUpdate,
    updated,
    isActive: row.is_active !== false,
    crowdEnabled: row.crowd_enabled !== false,
    menuPhotoUrls: Array.isArray(extra?.menu_photo_urls)
      ? (extra!.menu_photo_urls as unknown[]).map(String)
      : [],
    imageSource: typeof extra?.image_source === "string" ? extra.image_source : "google",
    ownerNotice: typeof extra?.owner_notice === "string" ? extra.owner_notice : "",
    createdAt: row.created_at ? new Date(String(row.created_at)) : new Date(0),
  };
}

export function totalReports(r: AdminRestaurant): number {
  const reports = r.reports ?? {};
  return Object.values(reports).reduce((a, b) => a + (Number(b) || 0), 0);
}

export async function fetchAdminRestaurants(): Promise<AdminRestaurant[]> {
  const now = new Date();
  // getDate() = 일(1–31). getDay()는 요일(0–6)이라 오늘 시작이 잘못 잡히던 버그.
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const weekAgo = new Date(todayStart);
  weekAgo.setDate(weekAgo.getDate() - 6);

  const [rowsRes, reportsRes, crowdRes, weekReportsRes] = await Promise.all([
    supabase.from("restaurants").select("*").order("created_at"),
    supabase
      .from("crowd_reports_for_stats")
      .select("restaurant_id, level, metadata, created_at, source")
      .gte("created_at", todayStart.toISOString()),
    supabase.from("crowd_status").select("*"),
    supabase
      .from("crowd_reports_for_stats")
      .select("restaurant_id, level, metadata, created_at, source")
      .gte("created_at", weekAgo.toISOString()),
  ]);

  if (rowsRes.error) throw rowsRes.error;
  if (reportsRes.error) throw reportsRes.error;

  const reportsById = new Map<string, Record<string, unknown>[]>();
  for (const raw of reportsRes.data ?? []) {
    const row = raw as Record<string, unknown>;
    const rid = String(row.restaurant_id);
    const list = reportsById.get(rid) ?? [];
    list.push(row);
    reportsById.set(rid, list);
  }
  for (const list of reportsById.values()) {
    list.sort(
      (a, b) =>
        new Date(String(b.created_at)).getTime() -
        new Date(String(a.created_at)).getTime(),
    );
  }

  const weekCountById = new Map<string, number>();
  for (const raw of weekReportsRes.data ?? []) {
    const row = raw as Record<string, unknown>;
    const source = String(row.source ?? "");
    if (source !== "user" && source !== "owner") continue;
    const rid = String(row.restaurant_id);
    weekCountById.set(rid, (weekCountById.get(rid) ?? 0) + 1);
  }

  const crowdById = new Map<string, Record<string, unknown>>();
  for (const raw of crowdRes.data ?? []) {
    const row = raw as Record<string, unknown>;
    crowdById.set(String(row.restaurant_id), row);
  }

  return (rowsRes.data ?? []).map((raw) => {
    const row = raw as Record<string, unknown>;
    const id = String(row.id);
    const merged = mergeRestaurant(
      row,
      reportsById.get(id) ?? [],
      crowdById.get(id),
    );
    merged.popularityScore = weekCountById.get(id) ?? totalReports(merged);
    return merged;
  });
}

export async function insertRestaurant(
  data: RestaurantFormData,
): Promise<void> {
  const desc: Record<string, unknown> = {
    hours: data.hours,
  };
  if (data.menu?.length) desc.menu = data.menu;
  if (data.kakao_place_id) desc.kakao_place_id = data.kakao_place_id;
  if (data.google_place_id) desc.google_place_id = data.google_place_id;
  if (data.hours_display) desc.hours_display = data.hours_display;
  if (data.hours_periods?.length) desc.hours_periods = data.hours_periods;

  const { error } = await supabase.from("restaurants").insert({
    name: data.name,
    category: data.category,
    area: data.area,
    address: data.address || data.area,
    image_url: data.image_url ?? "",
    description: JSON.stringify(desc),
    latitude: data.latitude ?? 0,
    longitude: data.longitude ?? 0,
    is_active: true,
    crowd_enabled: data.crowd_enabled ?? true,
  });

  if (error) throw error;
}

export async function updateRestaurant(
  id: string,
  data: Partial<RestaurantFormData>,
): Promise<void> {
  const patch: Record<string, unknown> = {};
  if (data.name != null) patch.name = data.name;
  if (data.category != null) patch.category = data.category;
  if (data.area != null) patch.area = data.area;
  if (data.address != null) patch.address = data.address;
  if (data.image_url != null) patch.image_url = data.image_url;
  if (data.crowd_enabled != null) patch.crowd_enabled = data.crowd_enabled;

  if (data.hours != null || data.menu != null) {
    const { data: existing, error: fetchErr } = await supabase
      .from("restaurants")
      .select("description")
      .eq("id", id)
      .single();
    if (fetchErr) throw fetchErr;
    const desc = parseDescription(existing?.description) ?? {};
    if (data.hours != null) desc.hours = data.hours;
    if (data.menu != null) desc.menu = data.menu;
    patch.description = JSON.stringify(desc);
  }

  const { data: updatedRows, error } = await supabase
    .from("restaurants")
    .update(patch)
    .eq("id", id)
    .select("id");
  if (error) throw error;
  if (!updatedRows?.length) {
    throw new Error("매장 수정 실패: 관리자 권한을 확인하세요.");
  }
}

/** 맛집컬렉션 전용 매장(crowd_enabled=false)을 제보 대상 매장으로 전환 */
export async function promoteToCrowdEnabled(id: string): Promise<void> {
  const { data: updatedRows, error } = await supabase
    .from("restaurants")
    .update({ crowd_enabled: true })
    .eq("id", id)
    .select("id");
  if (error) throw error;
  if (!updatedRows?.length) {
    throw new Error("승격 실패: 관리자 권한을 확인하세요.");
  }
}

export async function deleteRestaurant(id: string): Promise<void> {
  try {
    const { error } = await supabase.rpc("admin_delete_restaurant", {
      p_restaurant_id: id,
    });
    if (error) throw error;
    return;
  } catch (e) {
    const msg = errorMessage(e);
    if (
      !msg.includes("admin_delete_restaurant") &&
      !msg.includes("Could not find")
    ) {
      throw e;
    }
  }

  await supabase.from("crowd_reports").delete().eq("restaurant_id", id);
  await supabase.from("owner_seat_updates").delete().eq("restaurant_id", id);
  await supabase.from("crowd_status").delete().eq("restaurant_id", id);
  await supabase.from("analytics_events").delete().eq("restaurant_id", id);

  const { data, error } = await supabase
    .from("restaurants")
    .delete()
    .eq("id", id)
    .select("id");
  if (error) throw error;
  if (!data?.length) {
    throw new Error("매장 삭제에 실패했어요. 관리자 권한을 확인해주세요.");
  }
}

export async function findRestaurantIdByKakaoPlaceId(
  placeId: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("restaurants")
    .select("id, description");
  if (error) throw error;
  for (const raw of data ?? []) {
    const row = raw as Record<string, unknown>;
    const desc = parseDescription(row.description);
    const stored = desc?.kakao_place_id ?? desc?.google_place_id;
    if (stored === placeId) return String(row.id);
  }
  return null;
}

/** @deprecated use findRestaurantIdByKakaoPlaceId */
export async function findRestaurantIdByGooglePlaceId(
  placeId: string,
): Promise<string | null> {
  return findRestaurantIdByKakaoPlaceId(placeId);
}

export async function updateManualRanks(
  rankById: Record<string, number>,
): Promise<void> {
  for (const [id, rank] of Object.entries(rankById)) {
    const { data: existing, error: fetchErr } = await supabase
      .from("restaurants")
      .select("description")
      .eq("id", id)
      .single();
    if (fetchErr) throw fetchErr;
    const desc = parseDescription(existing?.description) ?? {};
    desc.manual_rank = rank;
    const { data, error } = await supabase
      .from("restaurants")
      .update({ description: JSON.stringify(desc) })
      .eq("id", id)
      .select("id");
    if (error) throw error;
    if (!data?.length) {
      throw new Error(`순위 저장 실패: ${id}`);
    }
  }
}

export async function fetchRecentCrowdReports(
  restaurantId: string,
  limit = 20,
): Promise<RecentCrowdReport[]> {
  const { data, error } = await supabase
    .from("crowd_reports")
    .select("id, level, source, metadata, created_at, user_id")
    .eq("restaurant_id", restaurantId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []).map((raw) => {
    const row = raw as Record<string, unknown>;
    const meta = (row.metadata as Record<string, unknown> | undefined) ?? {};
    return {
      id: String(row.id),
      status: crowdLevelToStatus(String(row.level ?? "normal"), meta),
      source: String(row.source ?? "user"),
      createdAt: new Date(String(row.created_at)),
      userId: row.user_id ? String(row.user_id) : null,
    };
  });
}

