import { supabase } from "./supabase";
import type {
  AdminRestaurant,
  MenuItem,
  RecentCrowdReport,
  RestaurantFormData,
} from "../types/restaurant";
import type { Gifticon } from "../types/gifticon";
import { parseAdminUser, type AdminUser } from "../types/user";
import {
  DEFAULT_PUSH_CONFIG,
  parsePushConfig,
  parsePushOpsSnapshot,
  EMPTY_PUSH_OPS,
  type PushNotificationConfig,
  type PushOpsSnapshot,
} from "../types/pushConfig";
import type { AppFeedback } from "../types/feedback";
import {
  parseBannedWord,
  parseCommunityNoticeAdmin,
  parseCommunityPostAdmin,
  parseCommunityReport,
  type BannedWord,
  type CommunityNoticeAdmin,
  type CommunityPostAdmin,
  type CommunityReport,
} from "../types/community";
import {
  parseCollectionCommentAdmin,
  parseCollectionItem,
  parseRestaurantCollection,
  type CollectionCommentAdmin,
  type CollectionItem,
  type RestaurantCollection,
} from "../types/collection";

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
    ownerCode: String(extra?.owner_code ?? ""),
    ownerRegistered: extra?.owner_registered === true,
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
  };
}

export function totalReports(r: AdminRestaurant): number {
  return Object.values(r.reports).reduce((a, b) => a + b, 0);
}

export async function fetchAdminRestaurants(): Promise<AdminRestaurant[]> {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDay());
  const weekAgo = new Date(todayStart);
  weekAgo.setDate(weekAgo.getDate() - 6);

  const [rowsRes, reportsRes, crowdRes, weekReportsRes] = await Promise.all([
    supabase.from("restaurants").select("*").order("created_at"),
    supabase
      .from("crowd_reports")
      .select("restaurant_id, level, metadata, created_at, source")
      .gte("created_at", todayStart.toISOString()),
    supabase.from("crowd_status").select("*"),
    supabase
      .from("crowd_reports")
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
): Promise<string> {
  const desc: Record<string, unknown> = {
    hours: data.hours,
    owner_code: String(100000 + Math.floor(Math.random() * 900000)),
  };
  if (data.menu?.length) desc.menu = data.menu;
  if (data.kakao_place_id) desc.kakao_place_id = data.kakao_place_id;
  if (data.google_place_id) desc.google_place_id = data.google_place_id;
  if (data.hours_display) desc.hours_display = data.hours_display;
  if (data.hours_periods?.length) desc.hours_periods = data.hours_periods;

  const { data: row, error } = await supabase
    .from("restaurants")
    .insert({
      name: data.name,
      category: data.category,
      area: data.area,
      address: data.address || data.area,
      image_url: data.image_url ?? "",
      description: JSON.stringify(desc),
      latitude: data.latitude ?? 0,
      longitude: data.longitude ?? 0,
      is_active: true,
    })
    .select("description")
    .single();

  if (error) throw error;
  const parsed = parseDescription(row?.description);
  return String(parsed?.owner_code ?? "");
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

export async function deleteRestaurant(id: string): Promise<void> {
  try {
    const { error } = await supabase.rpc("admin_delete_restaurant", {
      p_restaurant_id: id,
    });
    if (error) throw error;
    return;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
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
    throw new Error(
      "매장 삭제 실패: supabase/rpc_admin_restaurants.sql 실행·관리자 권한을 확인하세요.",
    );
  }
}

export async function generateOwnerCode(restaurantId: string): Promise<string> {
  const code = String(100000 + Math.floor(Math.random() * 900000));
  const { data: existing, error: fetchErr } = await supabase
    .from("restaurants")
    .select("description")
    .eq("id", restaurantId)
    .single();
  if (fetchErr) throw fetchErr;
  const desc = parseDescription(existing?.description) ?? {};
  desc.owner_code = code;
  const { data, error } = await supabase
    .from("restaurants")
    .update({ description: JSON.stringify(desc) })
    .eq("id", restaurantId)
    .select("id");
  if (error) throw error;
  if (!data?.length) {
    throw new Error("인증번호 저장 실패: 관리자 권한을 확인하세요.");
  }
  return code;
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

export async function uploadRestaurantImage(
  file: File,
): Promise<string> {
  const ext = file.name.split(".").pop()?.toLowerCase() || "jpg";
  const bucket = "restaurant-images";
  const path = `restaurants/${Date.now()}.${ext}`;
  const bytes = new Uint8Array(await file.arrayBuffer());

  try {
    await supabase.storage.createBucket(bucket, { public: true });
  } catch {
    /* bucket may exist */
  }

  const { error } = await supabase.storage.from(bucket).upload(path, bytes, {
    contentType: file.type || `image/${ext}`,
    upsert: true,
  });

  if (error) {
    const b64 = btoa(
      bytes.reduce((s, b) => s + String.fromCharCode(b), ""),
    );
    return `data:image/${ext};base64,${b64}`;
  }

  const { data } = supabase.storage.from(bucket).getPublicUrl(path);
  return data.publicUrl;
}

async function resolveGifticonImageUrl(raw: string | null | undefined): Promise<string> {
  if (!raw) return "";
  if (raw.startsWith("http")) return raw;
  try {
    const { data, error } = await supabase.storage
      .from("gifticons")
      .createSignedUrl(raw, 3600);
    if (error) return "";
    return data.signedUrl;
  } catch {
    return "";
  }
}

export async function fetchFeedback(): Promise<AppFeedback[]> {
  const { data, error } = await supabase
    .from("app_feedback")
    .select("id, category, content, user_id, created_at")
    .order("created_at", { ascending: false });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map((raw) => ({
    id: String(raw.id),
    category: String(raw.category ?? ""),
    content: String(raw.content ?? ""),
    userId: raw.user_id ? String(raw.user_id) : null,
    createdAt: new Date(String(raw.created_at)),
  }));
}

export async function fetchGifticons(): Promise<Gifticon[]> {
  const { data, error } = await supabase.rpc("admin_list_gifticons");
  if (error) throw error;
  if (!data) return [];
  const list: Gifticon[] = [];
  for (const raw of data as Record<string, unknown>[]) {
    const imageUrl = await resolveGifticonImageUrl(
      raw.image_url as string | undefined,
    );
    list.push({
      id: String(raw.id),
      brand: String(raw.brand ?? ""),
      productName: String(raw.product_name ?? ""),
      imageUrl,
      expiresAt: raw.expires_at
        ? new Date(String(raw.expires_at))
        : null,
      status: String(raw.status ?? "unassigned"),
      assignedUserId: raw.assigned_user_id
        ? String(raw.assigned_user_id)
        : null,
      assignedAt: raw.assigned_at
        ? new Date(String(raw.assigned_at))
        : null,
      createdAt: raw.created_at
        ? new Date(String(raw.created_at))
        : new Date(),
    });
  }
  return list;
}

export async function registerGifticon(params: {
  brand: string;
  productName: string;
  imageUrl: string;
  expiresAt?: Date;
}): Promise<void> {
  const payload: Record<string, string> = {
    p_brand: params.brand,
    p_product_name: params.productName,
    p_image_url: params.imageUrl,
  };
  if (params.expiresAt) {
    payload.p_expires_at = params.expiresAt.toISOString().slice(0, 10);
  }
  const { error } = await supabase.rpc("admin_register_gifticon", payload);
  if (error) throw error;
}

export async function uploadGifticonImage(file: File): Promise<string> {
  const uniqueName = `${Date.now()}_${file.name}`;
  const path = `gifticons/${uniqueName}`;
  const bytes = new Uint8Array(await file.arrayBuffer());
  const { error } = await supabase.storage.from("gifticons").upload(path, bytes, {
    upsert: false,
  });
  if (error) throw error;
  return path;
}

export async function bulkRegisterGifticons(
  rows: Array<Record<string, string>>,
): Promise<number> {
  const { data, error } = await supabase.rpc("admin_bulk_register_gifticons", {
    p_rows: rows,
  });
  if (error) throw error;
  const inserted =
    data && typeof data === "object" && !Array.isArray(data)
      ? Number((data as Record<string, unknown>).inserted ?? 0)
      : 0;
  return inserted;
}

export async function deleteGifticon(id: string): Promise<void> {
  const { data, error } = await supabase.rpc("admin_delete_gifticon", {
    p_gifticon_id: id,
  });
  if (error) throw error;
  if (!data || (data as Record<string, unknown>).status !== "ok") {
    throw new Error("삭제에 실패했어요.");
  }
  const imageUrl = String((data as Record<string, unknown>).image_url ?? "");
  if (imageUrl && !imageUrl.startsWith("http")) {
    const { error: storageErr } = await supabase.storage
      .from("gifticons")
      .remove([imageUrl]);
    if (storageErr) {
      console.warn("[Admin] gifticon storage remove failed:", storageErr.message);
    }
  }
}

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

export async function fetchPushNotificationConfig(): Promise<PushNotificationConfig> {
  const { data, error } = await supabase.rpc("get_push_notification_config");
  if (error) throw error;
  if (!data || typeof data !== "object") return DEFAULT_PUSH_CONFIG;
  return parsePushConfig(data as Record<string, unknown>);
}

export async function updatePushNotificationConfig(
  config: PushNotificationConfig,
): Promise<PushNotificationConfig> {
  const { data, error } = await supabase.rpc(
    "admin_update_push_notification_config",
    {
      p_lunch_hour: config.lunchHour,
      p_lunch_minute: config.lunchMinute,
      p_dinner_hour: config.dinnerHour,
      p_dinner_minute: config.dinnerMinute,
      p_title_template: config.titleTemplate,
      p_body_template: config.bodyTemplate,
      p_weekdays_only: config.weekdaysOnly,
      p_schedule_days_ahead: config.scheduleDaysAhead,
      p_peak_fcm_enabled: config.peakFcmEnabled,
      p_community_fcm_enabled: config.communityFcmEnabled,
      p_peak_local_schedule_enabled: config.peakLocalScheduleEnabled,
      p_community_comment_title_template: config.communityCommentTitleTemplate,
      p_community_comment_body_template: config.communityCommentBodyTemplate,
      p_community_like_title_template: config.communityLikeTitleTemplate,
      p_community_like_body_template: config.communityLikeBodyTemplate,
    },
  );
  if (error) throw error;
  if (!data || typeof data !== "object") {
    throw new Error("설정 저장 응답이 올바르지 않아요.");
  }
  return parsePushConfig(data as Record<string, unknown>);
}

export async function fetchPushOpsSnapshot(): Promise<PushOpsSnapshot> {
  const { data, error } = await supabase.rpc("admin_push_ops_snapshot");
  if (error) throw error;
  if (!data || typeof data !== "object") return EMPTY_PUSH_OPS;
  return parsePushOpsSnapshot(data as Record<string, unknown>);
}

/** Edge Function 호출 (로그인한 어드민 JWT). 배포·시크릿 필요. */
export async function invokePushEdge(
  action: "peak_lunch" | "peak_dinner" | "config_refresh",
): Promise<unknown> {
  if (action === "config_refresh") {
    const { data, error } = await supabase.functions.invoke(
      "send-config-refresh",
      { body: {} },
    );
    if (error) throw error;
    return data;
  }
  const force = action === "peak_lunch" ? "lunch" : "dinner";
  const { data, error } = await supabase.functions.invoke("send-peak-push", {
    body: { force },
  });
  if (error) throw error;
  return data;
}

export async function fetchCommunityReports(): Promise<CommunityReport[]> {
  const { data, error } = await supabase.rpc("admin_list_community_reports");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseCommunityReport(row as Record<string, unknown>));
}

export async function fetchCommunityPosts(): Promise<CommunityPostAdmin[]> {
  const { data, error } = await supabase.rpc("admin_list_community_posts", {
    p_limit: 50,
  });
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseCommunityPostAdmin(row as Record<string, unknown>));
}

export async function setCommunityPostHidden(
  id: string,
  hidden: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("community_posts")
    .update({ is_hidden: hidden })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCommunityPost(id: string): Promise<void> {
  const { error } = await supabase.from("community_posts").delete().eq("id", id);
  if (error) throw error;
}

export async function setCommunityCommentHidden(
  id: string,
  hidden: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("community_comments")
    .update({ is_hidden: hidden })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCommunityComment(id: string): Promise<void> {
  const { error } = await supabase.from("community_comments").delete().eq("id", id);
  if (error) throw error;
}

export async function fetchBannedWords(): Promise<BannedWord[]> {
  const { data, error } = await supabase
    .from("community_banned_words")
    .select("id, word, created_at")
    .order("word", { ascending: true });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map(parseBannedWord);
}

export async function addBannedWord(word: string): Promise<void> {
  const trimmed = word.trim();
  if (!trimmed) return;
  const { error } = await supabase
    .from("community_banned_words")
    .insert({ word: trimmed });
  if (error) throw error;
}

export async function deleteBannedWord(id: string): Promise<void> {
  const { error } = await supabase
    .from("community_banned_words")
    .delete()
    .eq("id", id);
  if (error) throw error;
}

export async function fetchCommunityNotices(): Promise<CommunityNoticeAdmin[]> {
  const { data, error } = await supabase
    .from("community_notices")
    .select("id, content, is_active, created_at")
    .order("created_at", { ascending: false });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map(parseCommunityNoticeAdmin);
}

export async function createCommunityNotice(content: string): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .insert({ content: content.trim() });
  if (error) throw error;
}

export async function updateCommunityNotice(
  id: string,
  content: string,
): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .update({ content: content.trim() })
    .eq("id", id);
  if (error) throw error;
}

export async function setCommunityNoticeActive(
  id: string,
  active: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .update({ is_active: active })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCommunityNotice(id: string): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .delete()
    .eq("id", id);
  if (error) throw error;
}

export async function fetchAdminCollections(): Promise<RestaurantCollection[]> {
  const { data, error } = await supabase
    .from("collections")
    .select("id, title, subtitle, sort_order, is_published, created_at")
    .order("sort_order", { ascending: true });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map(parseRestaurantCollection);
}

export async function createCollection(params: {
  title: string;
  subtitle: string;
  sortOrder: number;
}): Promise<void> {
  const { error } = await supabase.from("collections").insert({
    title: params.title.trim(),
    subtitle: params.subtitle.trim() || null,
    sort_order: params.sortOrder,
  });
  if (error) throw error;
}

export async function updateCollection(
  id: string,
  params: { title: string; subtitle: string; sortOrder: number },
): Promise<void> {
  const { error } = await supabase
    .from("collections")
    .update({
      title: params.title.trim(),
      subtitle: params.subtitle.trim() || null,
      sort_order: params.sortOrder,
    })
    .eq("id", id);
  if (error) throw error;
}

export async function setCollectionPublished(
  id: string,
  published: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("collections")
    .update({ is_published: published })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCollection(id: string): Promise<void> {
  const { error } = await supabase.from("collections").delete().eq("id", id);
  if (error) throw error;
}

export async function fetchCollectionItems(
  collectionId: string,
): Promise<CollectionItem[]> {
  const { data, error } = await supabase
    .from("collection_items")
    .select("id, collection_id, restaurant_id, note, sort_order, restaurants(name)")
    .eq("collection_id", collectionId)
    .order("sort_order", { ascending: true });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map((raw) => {
    const restaurant = raw.restaurants as { name?: string } | null;
    return parseCollectionItem({ ...raw, restaurant_name: restaurant?.name ?? null });
  });
}

export async function addCollectionItem(params: {
  collectionId: string;
  restaurantId: string;
  note: string;
  sortOrder: number;
}): Promise<void> {
  const { error } = await supabase.from("collection_items").insert({
    collection_id: params.collectionId,
    restaurant_id: params.restaurantId,
    note: params.note.trim() || null,
    sort_order: params.sortOrder,
  });
  if (error) throw error;
}

export async function removeCollectionItem(id: string): Promise<void> {
  const { error } = await supabase.from("collection_items").delete().eq("id", id);
  if (error) throw error;
}

export async function reorderCollectionItems(
  orderedIds: string[],
): Promise<void> {
  await Promise.all(
    orderedIds.map((id, index) =>
      supabase.from("collection_items").update({ sort_order: index }).eq("id", id),
    ),
  ).then((results) => {
    const failed = results.find((r) => r.error);
    if (failed?.error) throw failed.error;
  });
}

export async function fetchCollectionComments(): Promise<CollectionCommentAdmin[]> {
  const { data, error } = await supabase.rpc("admin_list_collection_comments", {
    p_limit: 100,
  });
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseCollectionCommentAdmin(row as Record<string, unknown>));
}

export async function setCollectionCommentHidden(
  id: string,
  hidden: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("collection_comments")
    .update({ is_hidden: hidden })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCollectionComment(id: string): Promise<void> {
  const { error } = await supabase.from("collection_comments").delete().eq("id", id);
  if (error) throw error;
}

export const AREAS = ["정문", "중문", "후문"] as const;
export const CATEGORIES = [
  "한식",
  "중식",
  "일식",
  "양식",
  "아시아",
  "분식",
  "카페",
] as const;
