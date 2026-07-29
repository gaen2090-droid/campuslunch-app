import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorizeRequest,
  corsPreflightResponse,
  getGoogleAccessToken,
  jsonResponse,
  loadServiceAccountFromEnv,
  sendFcmMessage,
} from "../_shared/fcm.ts";

/** 어드민 설정 변경 후 앱에 data-only로 로컬 스케줄 재동기화 신호 */
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

    const { data: tokens, error } = await supabase
      .from("user_push_tokens")
      .select("token");
    if (error) throw error;
    const list = (tokens ?? []) as { token: string }[];
    if (list.length === 0) {
      return jsonResponse({ ok: true, sent: 0, failed: 0 });
    }

    const sa = loadServiceAccountFromEnv();
    const access = await getGoogleAccessToken(sa);
    let sent = 0;
    let failed = 0;
    const invalidTokens: string[] = [];

    for (const row of list) {
      const result = await sendFcmMessage(sa, access, {
        token: row.token,
        dataOnly: true,
        data: { type: "config_refresh" },
      });
      if (result.ok) {
        sent++;
      } else {
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

    return jsonResponse({
      ok: true,
      sent,
      failed,
      pruned: invalidTokens.length,
    });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
