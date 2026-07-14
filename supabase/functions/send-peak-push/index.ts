import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorizeRequest,
  getGoogleAccessToken,
  jsonResponse,
  loadServiceAccountFromEnv,
  sendFcmMessage,
} from "../_shared/fcm.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }
  if (req.method !== "POST" && req.method !== "GET") {
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

    const { data: cfgRow, error: cfgErr } = await supabase.rpc(
      "get_push_notification_config",
    );
    if (cfgErr) throw cfgErr;
    const cfg = cfgRow as {
      lunch_hour: number;
      lunch_minute: number;
      dinner_hour: number;
      dinner_minute: number;
      title_template: string;
      body_template: string;
      weekdays_only: boolean;
      peak_fcm_enabled?: boolean;
    };

    if (cfg.peak_fcm_enabled === false) {
      return jsonResponse({ skipped: true, reason: "peak_fcm_disabled" });
    }

    let force: string | null = null;
    const url = new URL(req.url);
    force = url.searchParams.get("force");
    if (req.method === "POST") {
      try {
        const body = await req.json() as { force?: string };
        if (body.force === "lunch" || body.force === "dinner") {
          force = body.force;
        }
      } catch {
        /* empty body ok for cron */
      }
    }

    const now = new Date(
      new Date().toLocaleString("en-US", { timeZone: "Asia/Seoul" }),
    );
    const weekday = now.getDay();
    if (cfg.weekdays_only && (weekday === 0 || weekday === 6) && !force) {
      return jsonResponse({ skipped: true, reason: "weekend" });
    }

    const hour = now.getHours();
    const minute = now.getMinutes();
    let slot: "lunch" | "dinner" | null = null;
    if (hour === cfg.lunch_hour && minute === cfg.lunch_minute) slot = "lunch";
    if (hour === cfg.dinner_hour && minute === cfg.dinner_minute) {
      slot = "dinner";
    }
    if (force === "lunch" || force === "dinner") slot = force;

    if (!slot) {
      return jsonResponse({
        skipped: true,
        reason: "not_slot_time",
        kst: `${hour}:${minute}`,
      });
    }

    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, "0");
    const d = String(now.getDate()).padStart(2, "0");
    const dateStr = `${y}-${m}-${d}`;

    if (!force) {
      const { data: claimed, error: claimErr } = await supabase.rpc(
        "try_claim_peak_push",
        { p_slot: slot, p_date: dateStr },
      );
      if (claimErr) throw claimErr;
      if (!claimed) {
        return jsonResponse({ skipped: true, reason: "already_sent", slot });
      }
    }

    const { data: restRows, error: restErr } = await supabase.rpc(
      "pick_peak_push_restaurant",
    );
    if (restErr) throw restErr;
    const rest = Array.isArray(restRows) ? restRows[0] : restRows;
    if (!rest) {
      return jsonResponse({ skipped: true, reason: "no_available_restaurant" });
    }

    const gate = String(rest.gate ?? "캠퍼스");
    const title = String(cfg.title_template).replaceAll("{gate}", gate);
    const body = String(cfg.body_template);

    const { data: tokens, error: tokErr } = await supabase.rpc(
      "list_peak_push_tokens",
      { p_slot: slot },
    );
    if (tokErr) throw tokErr;
    const list = (tokens ?? []) as { user_id: string; token: string }[];
    if (list.length === 0) {
      return jsonResponse({ ok: true, slot, sent: 0, reason: "no_tokens" });
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
        body,
        data: {
          type: "peak",
          slot,
          restaurant_id: String(rest.restaurant_id),
          gate,
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

    return jsonResponse({
      ok: true,
      slot,
      sent,
      failed,
      restaurant_id: rest.restaurant_id,
      gate,
      forced: Boolean(force),
    });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
