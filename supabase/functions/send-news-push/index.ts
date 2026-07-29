import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorizeRequest,
  corsPreflightResponse,
  getGoogleAccessToken,
  jsonResponse,
  loadServiceAccountFromEnv,
  sendFcmMessage,
} from "../_shared/fcm.ts";

type Cfg = {
  news_fcm_enabled?: boolean;
};

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
    const title = String(body.title ?? "").trim();
    const text = String(body.body ?? "").trim();
    if (!title || !text) {
      return jsonResponse({ error: "title/body가 필요해요" }, 400);
    }

    const { data: cfgRow } = await supabase.rpc("get_push_notification_config");
    const cfg = (cfgRow ?? {}) as Cfg;
    if (cfg.news_fcm_enabled === false) {
      return jsonResponse({ skipped: true, reason: "news_fcm_disabled" });
    }

    const { data: tokens, error } = await supabase.rpc("list_news_push_tokens");
    if (error) throw error;
    const list = (tokens ?? []) as { token: string }[];
    if (list.length === 0) {
      return jsonResponse({ ok: true, sent: 0, failed: 0, skipped: "no_tokens" });
    }

    const sa = loadServiceAccountFromEnv();
    const access = await getGoogleAccessToken(sa);

    let sent = 0;
    let failed = 0;
    const invalidTokens: string[] = [];

    for (const row of list) {
      const result = await sendFcmMessage(sa, access, {
        token: row.token,
        title,
        body: text,
        data: { type: "news" },
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
      await supabase.from("user_push_tokens").delete().in("token", invalidTokens);
    }

    await supabase.rpc("admin_log_news_push", {
      p_title: title,
      p_body: text,
      p_sent_count: sent,
      p_failed_count: failed,
    });

    return jsonResponse({ ok: true, sent, failed });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
