import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsPreflightResponse, jsonResponse } from "../_shared/fcm.ts";

const SEND_URL =
  Deno.env.get("GIFTISHOW_SEND_URL") ??
  "https://bizapi.giftishow.com/bizApi/send";
const CANCEL_URL =
  Deno.env.get("GIFTISHOW_CANCEL_URL") ??
  "https://bizapi.giftishow.com/bizApi/cancel";
const BALANCE_URL =
  Deno.env.get("GIFTISHOW_BALANCE_URL") ??
  "https://bizapi.giftishow.com/bizApi/bizmoney";

type Creds = {
  authCode: string;
  authToken: string;
  userId: string;
  callbackNo: string;
  phoneNo: string;
};

function creds(): Creds | null {
  const authCode = Deno.env.get("GIFTISHOW_AUTH_CODE") ?? "";
  const authToken = Deno.env.get("GIFTISHOW_AUTH_TOKEN") ?? "";
  const userId = Deno.env.get("GIFTISHOW_USER_ID") ?? "";
  const callbackNo = (Deno.env.get("GIFTISHOW_CALLBACK_NO") ?? "").replace(
    /\D/g,
    "",
  );
  const phoneNo = (Deno.env.get("GIFTISHOW_PHONE_NO") ?? callbackNo).replace(
    /\D/g,
    "",
  );
  if (!authCode || !authToken || !userId || !callbackNo || !phoneNo) {
    return null;
  }
  return { authCode, authToken, userId, callbackNo, phoneNo };
}

function formBody(fields: Record<string, string>): string {
  return new URLSearchParams(fields).toString();
}

async function giftishowPost(
  url: string,
  fields: Record<string, string>,
): Promise<Record<string, unknown>> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: formBody(fields),
    signal: AbortSignal.timeout(15_000),
  });
  const text = await res.text();
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return { code: "parse", message: text.slice(0, 300), http: res.status };
  }
}

function resultPin(payload: Record<string, unknown>): {
  pinNo: string;
  orderNo: string;
  couponImgUrl: string;
} {
  const top = (payload.result ?? payload) as Record<string, unknown>;
  const nested =
    top && typeof top.result === "object" && top.result
      ? (top.result as Record<string, unknown>)
      : top;
  return {
    pinNo: String(nested.pinNo ?? nested.pin_no ?? ""),
    orderNo: String(nested.orderNo ?? nested.order_no ?? ""),
    couponImgUrl: String(nested.couponImgUrl ?? nested.coupon_img_url ?? ""),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "supabase env missing" }, 500);
  }
  const admin = createClient(supabaseUrl, serviceKey);

  const auth = req.headers.get("Authorization") ?? "";
  const jwt = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (!jwt) return jsonResponse({ error: "unauthorized" }, 401);

  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData.user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  const uid = userData.user.id;
  const { data: profile } = await admin
    .from("users")
    .select("role")
    .eq("id", uid)
    .maybeSingle();
  const isAdmin = profile?.role === "admin";

  let body: Record<string, unknown> = {};
  try {
    body = await req.json() as Record<string, unknown>;
  } catch {
    body = {};
  }

  const action = String(body.action ?? "issue");
  const keys = creds();

  if (action === "balance") {
    if (!isAdmin) return jsonResponse({ error: "forbidden" }, 403);
    if (!keys) {
      return jsonResponse({
        ok: false,
        reason: "not_configured",
        message: "기프티쇼 시크릿이 아직 없어요.",
      });
    }
    const payload = await giftishowPost(BALANCE_URL, {
      api_code: "0301",
      custom_auth_code: keys.authCode,
      custom_auth_token: keys.authToken,
      dev_yn: "N",
      user_id: keys.userId,
    });
    const code = String(payload.code ?? "");
    return jsonResponse({
      ok: code === "0000",
      balance: payload.balance ?? null,
      message: payload.message ?? null,
      code,
    });
  }

  const issuanceId = String(body.issuance_id ?? "");
  if (!issuanceId) {
    return jsonResponse({ error: "issuance_id required" }, 400);
  }

  const { data: ownerRow, error: ownerErr } = await admin
    .from("giftishow_issuances")
    .select("user_id, status")
    .eq("id", issuanceId)
    .maybeSingle();
  if (ownerErr || !ownerRow) {
    return jsonResponse({ ok: false, reason: "missing" }, 404);
  }
  if (!isAdmin && ownerRow.user_id !== uid) {
    return jsonResponse({ error: "forbidden" }, 403);
  }
  if (ownerRow.status === "issued") {
    return jsonResponse({ ok: true, status: "issued" });
  }
  if (ownerRow.status === "failed") {
    return jsonResponse({ ok: false, reason: "failed" });
  }

  if (!keys) {
    await admin.rpc("giftishow_fail_issuance", {
      p_issuance_id: issuanceId,
      p_error: "not_configured",
    });
    return jsonResponse({
      ok: false,
      reason: "not_configured",
      message:
        "기프티쇼 계약·API 키가 아직 없어요. 스탬프 20개를 되돌렸어요.",
    });
  }

  const { data: claim, error: claimErr } = await admin.rpc(
    "giftishow_claim_issuance",
    { p_issuance_id: issuanceId },
  );
  if (claimErr) {
    return jsonResponse({ ok: false, reason: claimErr.message }, 500);
  }
  const claimed = claim as Record<string, unknown>;
  if (claimed.status === "issued") {
    return jsonResponse({ ok: true, status: "issued" });
  }
  if (claimed.claimed !== true) {
    return jsonResponse({ ok: false, reason: "in_progress" });
  }

  const trId = String(claimed.tr_id ?? "");
  const goodsCode = String(claimed.goods_code ?? "");
  const title = "캠퍼스런치";
  const brand = String(claimed.brand ?? "");
  const productName = String(claimed.product_name ?? "기프티콘");

  let payload: Record<string, unknown>;
  try {
    payload = await giftishowPost(SEND_URL, {
      api_code: "0204",
      custom_auth_code: keys.authCode,
      custom_auth_token: keys.authToken,
      dev_yn: "N",
      goods_code: goodsCode,
      mms_title: title.slice(0, 10),
      mms_msg: `${brand} ${productName}`.trim().slice(0, 100),
      callback_no: keys.callbackNo,
      phone_no: keys.phoneNo,
      tr_id: trId,
      user_id: keys.userId,
      gubun: "I",
    });
  } catch (e) {
    await giftishowPost(CANCEL_URL, {
      api_code: "0202",
      custom_auth_code: keys.authCode,
      custom_auth_token: keys.authToken,
      dev_yn: "N",
      tr_id: trId,
      user_id: keys.userId,
    }).catch(() => undefined);
    await admin.rpc("giftishow_fail_issuance", {
      p_issuance_id: issuanceId,
      p_error: e instanceof Error ? e.message : "timeout",
    });
    return jsonResponse({
      ok: false,
      reason: "timeout",
      message: "기프티쇼 응답이 없어 발급을 취소하고 스탬프를 되돌렸어요.",
    });
  }

  const code = String(payload.code ?? "");
  if (code !== "0000") {
    await admin.rpc("giftishow_fail_issuance", {
      p_issuance_id: issuanceId,
      p_error: `${code} ${String(payload.message ?? "")}`,
    });
    return jsonResponse({
      ok: false,
      reason: "giftishow",
      code,
      message: String(payload.message ?? "기프티쇼 발급에 실패했어요."),
    });
  }

  const pin = resultPin(payload);
  const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
  const { error: doneErr } = await admin.rpc("giftishow_complete_issuance", {
    p_issuance_id: issuanceId,
    p_pin_no: pin.pinNo,
    p_order_no: pin.orderNo,
    p_coupon_image_url: pin.couponImgUrl,
    p_expires_at: expires,
  });
  if (doneErr) {
    return jsonResponse({ ok: false, reason: doneErr.message }, 500);
  }
  return jsonResponse({ ok: true, status: "issued", order_no: pin.orderNo });
});
