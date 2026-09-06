import { supabase } from "./supabase";
import type { OwnerApplication } from "../types/ownerApplication";
import type { AppFeedback } from "../types/feedback";

export async function fetchOwnerApplications(): Promise<OwnerApplication[]> {
  const { data, error } = await supabase.rpc("admin_list_owner_applications");
  if (error) throw error;
  return (data ?? []).map((raw: Record<string, unknown>) => ({
    id: String(raw.id),
    userId: String(raw.user_id),
    userNickname: String(raw.user_nickname ?? ""),
    restaurantId: String(raw.restaurant_id),
    restaurantName: String(raw.restaurant_name ?? ""),
    phone: String(raw.phone ?? ""),
    email: String(raw.email ?? ""),
    licensePaths: Array.isArray(raw.license_paths)
      ? (raw.license_paths as string[])
      : [],
    status: String(raw.status ?? "pending"),
    rejectReason: raw.reject_reason ? String(raw.reject_reason) : null,
    notifyPush: Boolean(raw.notify_push),
    notifySms: Boolean(raw.notify_sms),
    createdAt: new Date(String(raw.created_at)),
    reviewedAt: raw.reviewed_at ? new Date(String(raw.reviewed_at)) : null,
  }));
}

export async function reviewOwnerApplication(
  applicationId: string,
  approve: boolean,
  rejectReason?: string,
): Promise<void> {
  const { error } = await supabase.rpc("admin_review_owner_application", {
    p_application_id: applicationId,
    p_approve: approve,
    p_reject_reason: rejectReason ?? null,
  });
  if (error) throw error;
}

export async function resolveOwnerLicenseUrl(path: string): Promise<string> {
  const { data, error } = await supabase.storage
    .from("owner-licenses")
    .createSignedUrl(path, 3600);
  if (error || !data) return "";
  return data.signedUrl;
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

/**
 * Google Place Photo(만료되는 photo_reference 링크)를 내려받아 Storage에 영구 저장.
 * 실패 시 null — 호출부는 image_url을 빈 값으로 두고 계속 진행해야 한다.
 */
export async function persistGooglePhoto(photoUrl: string): Promise<string | null> {
  try {
    const res = await fetch(photoUrl);
    if (!res.ok) return null;
    const contentType = res.headers.get("content-type") || "image/jpeg";
    const ext = contentType.includes("png") ? "png" : "jpg";
    const bytes = new Uint8Array(await res.arrayBuffer());

    const bucket = "restaurant-images";
    const path = `restaurants/${Date.now()}.${ext}`;

    try {
      await supabase.storage.createBucket(bucket, { public: true });
    } catch {
      /* bucket may exist */
    }

    const { error } = await supabase.storage.from(bucket).upload(path, bytes, {
      contentType,
      upsert: true,
    });
    if (error) return null;

    const { data } = supabase.storage.from(bucket).getPublicUrl(path);
    return data.publicUrl;
  } catch {
    return null;
  }
}

export async function fetchFeedback(): Promise<AppFeedback[]> {
  const { data, error } = await supabase.rpc("admin_list_feedback");
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map((raw) => ({
    id: String(raw.id),
    category: String(raw.category ?? ""),
    content: String(raw.content ?? ""),
    userId: raw.user_id ? String(raw.user_id) : null,
    nickname: String(raw.nickname ?? ""),
    isFromOwner: raw.is_from_owner === true,
    createdAt: new Date(String(raw.created_at)),
  }));
}

