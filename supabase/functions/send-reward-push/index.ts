import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorizeRequest,
  corsPreflightResponse,
  getGoogleAccessToken,
  jsonResponse,
  loadServiceAccountFromEnv,
  sendFcmMessage,
} from "../_shared/fcm.ts";

type Payload = {
  user_id: string;
  gifticon_id: string;
  brand?: string;
  product_name?: string;
};

function extractPayload(body: Record<string, unknown>): Payload | null {
  const userId = String(body.user_id ?? "");
  const gifticonId = String(body.gifticon_id ?? "");
  if (!userId || !gifticonId) return null;
  return {
    user_id: userId,
    gifticon_id: gifticonId,
    brand: typeof body.brand === "string" ? body.brand : undefined,
    product_name:
      typeof body.product_name === "string" ? body.product_name : undefined,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return corsPreflightResponse();
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }
  if (!(await authorizeRequest(req))) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const body = await req.json() as Record<string, unknown>;
    const payload = extractPayload(body);
    if (!payload) {
      return jsonResponse({ error: "invalid payload" }, 400);
    }

    const { data: tokens, error } = await supabase.rpc(
      "list_reward_push_tokens",
      { p_user_id: payload.user_id },
    );
    if (error) throw error;
    const list = (tokens ?? []) as { token: string }[];
    if (list.length === 0) {
      return jsonResponse({ ok: true, sent: 0, failed: 0, skipped: "no_tokens_or_opted_out" });
    }

    const sa = loadServiceAccountFromEnv();
    const access = await getGoogleAccessToken(sa);

    const productLabel = payload.product_name
      ? `${payload.brand ? `${payload.brand} ` : ""}${payload.product_name}`
      : "기프티콘";
    const title = "리워드가 지급됐어요";
    const body_ = `${productLabel}이(가) 쿠폰함에 도착했어요.`;

    let sent = 0;
    let failed = 0;
    const invalidTokens: string[] = [];

    for (const row of list) {
      const result = await sendFcmMessage(sa, access, {
        token: row.token,
        title,
        body: body_,
        data: {
          type: "reward_gifticon",
          gifticon_id: payload.gifticon_id,
        },
      });
      if (result.ok) sent++;
      else {
        failed++;
        if (
          result.status === 404 ||
          result.body.includes("UNREGISTERED") ||
          result.body.includes("NOT_FOUND")
        ) {
          invalidTokens.push(row.token);
        }
      }
    }

    if (invalidTokens.length > 0) {
      await supabase.from("user_push_tokens").delete().in(
        "token",
        invalidTokens,
      );
    }

    return jsonResponse({ ok: true, sent, failed });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
