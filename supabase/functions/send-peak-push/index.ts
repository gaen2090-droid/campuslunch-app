import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorizeRequest,
  corsPreflightResponse,
  getGoogleAccessToken,
  jsonResponse,
  loadServiceAccountFromEnv,
  sendFcmMessage,
} from "../_shared/fcm.ts";

type PeakSchedule = {
  id: string;
  label?: string;
  enabled?: boolean;
  hour: number;
  minute: number;
  title_template: string;
  body_template: string;
  fallback_title_template: string;
  fallback_body_template: string;
};

function stripGate(text: string): string {
  return text.replaceAll("{gate}", "").replace(/\s{2,}/g, " ").trim();
}

const DEFAULT_TITLE = "{restaurant}에서 대기없이 식사할 수 있어요";
const DEFAULT_BODY = "다른 매장도 확인해보기 >";
const DEFAULT_FALLBACK_TITLE = "대기 없이 식사할 수 있어요";
const DEFAULT_FALLBACK_BODY =
  "지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >";

function nonEmpty(v: unknown, fallback: string): string {
  const s = typeof v === "string" ? v.trim() : "";
  return s || fallback;
}

function parseSchedules(cfg: Record<string, unknown>): PeakSchedule[] {
  const raw = cfg.peak_schedules;
  if (Array.isArray(raw) && raw.length > 0) {
    return raw.map((row, i) => {
      const r = row as Record<string, unknown>;
      return {
        id: String(r.id ?? `slot_${i}`),
        label: String(r.label ?? ""),
        enabled: r.enabled !== false,
        hour: Number(r.hour ?? 12),
        minute: Number(r.minute ?? 0),
        title_template: stripGate(nonEmpty(r.title_template, DEFAULT_TITLE)),
        body_template: stripGate(nonEmpty(r.body_template, DEFAULT_BODY)),
        fallback_title_template: stripGate(
          nonEmpty(r.fallback_title_template, DEFAULT_FALLBACK_TITLE),
        ),
        fallback_body_template: stripGate(
          nonEmpty(r.fallback_body_template, DEFAULT_FALLBACK_BODY),
        ),
      };
    }).filter((s) =>
      s.title_template && s.body_template &&
      s.fallback_title_template && s.fallback_body_template
    );
  }
  // legacy lunch/dinner
  const fallbackTitle = stripGate(
    nonEmpty(cfg.title_template, DEFAULT_FALLBACK_TITLE),
  );
  const fallbackBody = stripGate(
    nonEmpty(cfg.body_template, DEFAULT_FALLBACK_BODY),
  );
  return [
    {
      id: "lunch",
      enabled: true,
      hour: Number(cfg.lunch_hour ?? 12),
      minute: Number(cfg.lunch_minute ?? 0),
      title_template: DEFAULT_TITLE,
      body_template: DEFAULT_BODY,
      fallback_title_template: fallbackTitle,
      fallback_body_template: fallbackBody,
    },
    {
      id: "dinner",
      enabled: true,
      hour: Number(cfg.dinner_hour ?? 18),
      minute: Number(cfg.dinner_minute ?? 0),
      title_template: DEFAULT_TITLE,
      body_template: DEFAULT_BODY,
      fallback_title_template: fallbackTitle,
      fallback_body_template: fallbackBody,
    },
  ];
}

function applyRestaurant(template: string, restaurantName: string): string {
  return template.replaceAll("{restaurant}", restaurantName);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return corsPreflightResponse();
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
    const cfg = cfgRow as Record<string, unknown>;

    if (cfg.peak_fcm_enabled === false) {
      return jsonResponse({ skipped: true, reason: "peak_fcm_disabled" });
    }

    let force: string | null = null;
    const url = new URL(req.url);
    force = url.searchParams.get("force");
    if (req.method === "POST") {
      try {
        const body = await req.json() as { force?: string };
        if (body.force) force = body.force;
      } catch {
        /* empty body ok for cron */
      }
    }
    if (force === "peak_lunch") force = "lunch";
    if (force === "peak_dinner") force = "dinner";

    const now = new Date(
      new Date().toLocaleString("en-US", { timeZone: "Asia/Seoul" }),
    );
    const weekday = now.getDay();
    if (cfg.weekdays_only && (weekday === 0 || weekday === 6) && !force) {
      return jsonResponse({ skipped: true, reason: "weekend" });
    }

    const schedules = parseSchedules(cfg).filter((s) => s.enabled !== false);
    const hour = now.getHours();
    const minute = now.getMinutes();

    let matched: PeakSchedule | null = null;
    if (force) {
      matched = schedules.find((s) => s.id === force) ?? null;
      // allow force even if disabled (admin test)
      if (!matched) {
        matched = parseSchedules(cfg).find((s) => s.id === force) ?? null;
      }
    } else {
      matched = schedules.find((s) => s.hour === hour && s.minute === minute) ??
        null;
    }

    if (!matched) {
      return jsonResponse({
        skipped: true,
        reason: "not_slot_time",
        kst: `${hour}:${minute}`,
      });
    }

    const slot = matched.id;
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, "0");
    const d = String(now.getDate()).padStart(2, "0");
    const dateStr = `${y}-${m}-${d}`;

    if (!force) {
      const { data: claimed, error: claimErr } = await supabase.rpc(
        "try_claim_peak_push",
        {
          p_slot: slot,
          p_date: dateStr,
          p_hour: matched.hour,
          p_minute: matched.minute,
        },
      );
      if (claimErr) throw claimErr;
      if (!claimed) {
        return jsonResponse({
          skipped: true,
          reason: "already_sent",
          slot,
          hour: matched.hour,
          minute: matched.minute,
        });
      }
    }

    const { data: targets, error: targetsErr } = await supabase.rpc(
      "list_peak_push_targets",
      { p_slot: slot },
    );
    if (targetsErr) throw targetsErr;
    const list = (targets ?? []) as {
      user_id: string;
      token: string;
      restaurant_id: string | null;
      restaurant_name: string | null;
    }[];
    if (list.length === 0) {
      return jsonResponse({ ok: true, slot, sent: 0, reason: "no_tokens" });
    }

    const sa = loadServiceAccountFromEnv();
    const access = await getGoogleAccessToken(sa);
    let sent = 0;
    let failed = 0;
    let personalized = 0;
    let fallback = 0;
    const invalidTokens: string[] = [];

    for (const row of list) {
      const hasRestaurant = Boolean(row.restaurant_id && row.restaurant_name);
      const title = hasRestaurant
        ? applyRestaurant(matched.title_template, row.restaurant_name!)
        : matched.fallback_title_template;
      const body = hasRestaurant
        ? applyRestaurant(matched.body_template, row.restaurant_name!)
        : matched.fallback_body_template;

      const data: Record<string, string> = { type: "peak", slot };
      if (hasRestaurant) {
        data.restaurant_id = row.restaurant_id!;
      }

      const result = await sendFcmMessage(sa, access, {
        token: row.token,
        title,
        body,
        data,
      });
      if (result.ok) {
        sent++;
        if (hasRestaurant) personalized++;
        else fallback++;
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
      slot,
      sent,
      failed,
      personalized,
      fallback,
      forced: Boolean(force),
    });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
