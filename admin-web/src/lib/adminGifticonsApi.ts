import { supabase } from "./supabase";
import type { Gifticon } from "../types/gifticon";
import { resolveGifticonFaceValueKrw } from "../types/gifticon";
import type { RewardSpendReport, RewardSpendUserRow } from "../types/rewardSpend";

// from("gifticons")가 이미 버킷을 지정하므로, image_url("gifticons/<name>")에서
// 접두사를 뗀 버킷 내부 객체 key만 storage API에 넘겨야 한다.
function gifticonObjectKey(raw: string): string {
  return raw.startsWith("gifticons/") ? raw.slice("gifticons/".length) : raw;
}

async function resolveGifticonImageUrl(
  raw: string | null | undefined,
): Promise<string> {
  if (!raw) return "";
  if (raw.startsWith("http")) return raw;
  const objectKey = gifticonObjectKey(raw);
  try {
    const { data, error } = await supabase.storage
      .from("gifticons")
      .createSignedUrl(objectKey, 3600);
    if (error) return "";
    return data.signedUrl;
  } catch {
    return "";
  }
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
      faceValue:
        typeof raw.face_value === "number"
          ? raw.face_value
          : raw.face_value != null
            ? Number.parseInt(String(raw.face_value), 10) || null
            : null,
    });
  }
  return list;
}

export async function registerGifticon(params: {
  brand: string;
  productName: string;
  imageUrl: string;
  expiresAt?: Date;
  faceValue?: number;
}): Promise<void> {
  const payload: Record<string, string | number> = {
    p_brand: params.brand,
    p_product_name: params.productName,
    p_image_url: params.imageUrl,
  };
  if (params.expiresAt) {
    payload.p_expires_at = params.expiresAt.toISOString().slice(0, 10);
  }
  if (params.faceValue != null && Number.isFinite(params.faceValue)) {
    payload.p_face_value = Math.trunc(params.faceValue);
  }
  const { error } = await supabase.rpc("admin_register_gifticon", payload);
  if (error) throw error;
}

let uploadSeq = 0;

export async function uploadGifticonImage(file: File): Promise<string> {
  const ext = file.name.match(/\.[a-zA-Z0-9]+$/)?.[0]?.toLowerCase() || "";
  const uniqueName = `${Date.now()}_${uploadSeq++}_${crypto.randomUUID()}${ext}`;
  // storage.objects RLS는 image_url을 "bucket_id || '/' || name" 형태로 비교하므로,
  // DB에는 gifticons/<name>을 저장하되 upload() 호출 자체엔 버킷 내부 상대경로(name)만 넘긴다.
  // from("gifticons")가 이미 버킷을 지정하므로 여기에 다시 "gifticons/"를 붙이면
  // 객체가 gifticons/gifticons/<name>에 저장되어 RLS의 image_url 매칭이 깨진다.
  const bytes = new Uint8Array(await file.arrayBuffer());
  const { error } = await supabase.storage
    .from("gifticons")
    .upload(uniqueName, bytes, {
      upsert: false,
      contentType: file.type || "application/octet-stream",
    });
  if (error) throw error;
  return `gifticons/${uniqueName}`;
}

export async function bulkRegisterGifticons(
  rows: Array<Record<string, string | number>>,
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



export async function fetchRewardSpendReport(): Promise<RewardSpendReport> {
  const { data, error } = await supabase.rpc("admin_reward_spend_report");
  if (error) throw error;
  const map =
    data && typeof data === "object" && !Array.isArray(data)
      ? (data as Record<string, unknown>)
      : {};

  // 신버전 RPC: 서버에서 유저별 집계된 users 배열 (+ totals)
  if (Array.isArray(map.users)) {
    const users: RewardSpendUserRow[] = map.users
      .filter((u): u is Record<string, unknown> => !!u && typeof u === "object")
      .map((u) => ({
        userId: String(u.user_id ?? u.userId ?? ""),
        nickname: String(u.nickname ?? ""),
        email: String(u.email ?? ""),
        rewardCount: Number(u.reward_count ?? u.rewardCount ?? 0) || 0,
        amountKrw: Number(u.amount_krw ?? u.amountKrw ?? 0) || 0,
      }))
      .filter((u) => u.userId.length > 0)
      .sort(
        (a, b) => b.rewardCount - a.rewardCount || b.amountKrw - a.amountKrw,
      );
    return {
      totalRewardCount: Number(map.total_reward_count ?? 0) || 0,
      totalAmountKrw: Number(map.total_amount_krw ?? 0) || 0,
      attributedCount: Number(map.attributed_count ?? 0) || 0,
      unattributedCount: Number(map.unattributed_count ?? 0) || 0,
      missingFaceValueCount: Number(map.missing_face_value_count ?? 0) || 0,
      users,
    };
  }

  // 구버전 RPC 호환: gifts 원본 → 클라이언트 집계 (대량 시 타임아웃/용량 이슈 가능)
  const giftsRaw = Array.isArray(map.gifts) ? map.gifts : [];

  type Agg = {
    userId: string;
    nickname: string;
    email: string;
    rewardCount: number;
    amountKrw: number;
  };
  const byUser = new Map<string, Agg>();
  let totalRewardCount = 0;
  let totalAmountKrw = 0;
  let attributedCount = 0;
  let unattributedCount = 0;
  let missingFaceValueCount = 0;

  for (const item of giftsRaw) {
    if (!item || typeof item !== "object") continue;
    const raw = item as Record<string, unknown>;
    const productName = String(raw.product_name ?? "");
    const faceRaw =
      typeof raw.face_value === "number"
        ? raw.face_value
        : raw.face_value != null
          ? Number.parseInt(String(raw.face_value), 10)
          : null;
    if (faceRaw == null || !Number.isFinite(faceRaw) || faceRaw <= 0) {
      missingFaceValueCount += 1;
    }
    const amount = resolveGifticonFaceValueKrw(
      Number.isFinite(faceRaw as number) ? (faceRaw as number) : null,
      productName,
    );
    totalRewardCount += 1;
    totalAmountKrw += amount;

    const userId = raw.user_id ? String(raw.user_id) : "";
    if (!userId) {
      unattributedCount += 1;
      continue;
    }
    attributedCount += 1;
    const prev = byUser.get(userId);
    if (prev) {
      prev.rewardCount += 1;
      prev.amountKrw += amount;
    } else {
      byUser.set(userId, {
        userId,
        nickname: String(raw.nickname ?? ""),
        email: String(raw.email ?? ""),
        rewardCount: 1,
        amountKrw: amount,
      });
    }
  }

  const users = [...byUser.values()].sort(
    (a, b) => b.rewardCount - a.rewardCount || b.amountKrw - a.amountKrw,
  );

  return {
    totalRewardCount,
    totalAmountKrw,
    attributedCount,
    unattributedCount,
    missingFaceValueCount,
    users,
  };
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
      .remove([gifticonObjectKey(imageUrl)]);
    if (storageErr) {
      console.warn("[Admin] gifticon storage remove failed:", storageErr.message);
    }
  }
}

/** 여러 기프티콘을 한 번에 삭제. 실패한 건은 건너뛰고 성공 개수만 반환한다. */
export async function bulkDeleteGifticons(ids: string[]): Promise<number> {
  let deleted = 0;
  for (const id of ids) {
    try {
      await deleteGifticon(id);
      deleted++;
    } catch (err) {
      console.warn("[Admin] bulkDeleteGifticons failed for", id, err);
    }
  }
  return deleted;
}

