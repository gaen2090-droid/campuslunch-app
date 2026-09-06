import { supabase } from "./supabase";
import {
  DEFAULT_PUSH_CONFIG,
  parsePushConfig,
  parsePushOpsSnapshot,
  parseScheduledNewsPush,
  schedulesToJson,
  EMPTY_PUSH_OPS,
  type NewsPushTarget,
  type PushNotificationConfig,
  type PushOpsSnapshot,
  type ScheduledNewsPush,
} from "../types/pushConfig";

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
      p_peak_schedules: schedulesToJson(config.schedules),
      p_weekdays_only: config.weekdaysOnly,
      p_schedule_days_ahead: config.scheduleDaysAhead,
      p_peak_fcm_enabled: config.peakFcmEnabled,
      p_community_fcm_enabled: config.communityFcmEnabled,
      p_peak_local_schedule_enabled: config.peakLocalScheduleEnabled,
      p_community_comment_title_template: config.communityCommentTitleTemplate,
      p_community_comment_body_template: config.communityCommentBodyTemplate,
      p_news_fcm_enabled: config.newsFcmEnabled,
      p_community_reply_title_template: config.communityReplyTitleTemplate,
      p_community_reply_body_template: config.communityReplyBodyTemplate,
      p_peak_exclude_owners: config.peakExcludeOwners,
      p_news_exclude_owners: config.newsExcludeOwners,
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
  action: string,
): Promise<unknown> {
  const { data: sessionData } = await supabase.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) {
    throw new Error("로그인이 만료됐어요. 다시 로그인해 주세요.");
  }

  const baseUrl = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.replace(
    /\/$/,
    "",
  );
  const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
  if (!baseUrl || !anonKey) {
    throw new Error("Supabase URL/anon key가 없어요.");
  }

  const name =
    action === "config_refresh" ? "send-config-refresh" : "send-peak-push";
  const force =
    action === "config_refresh"
      ? undefined
      : action === "peak_lunch"
        ? "lunch"
        : action === "peak_dinner"
          ? "dinner"
          : action;
  const body =
    name === "send-peak-push" ? { force } : {};

  const res = await fetch(`${baseUrl}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      apikey: anonKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const text = await res.text();
  let parsed: unknown = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }

  if (!res.ok) {
    const msg =
      parsed &&
      typeof parsed === "object" &&
      parsed !== null &&
      "error" in parsed
        ? String((parsed as { error: unknown }).error)
        : text || res.statusText;
    throw new Error(`${res.status}: ${msg}`);
  }

  return parsed;
}

export async function fetchNewsPushReach(
  target: NewsPushTarget,
): Promise<{ users: number; devices: number }> {
  const { data, error } = await supabase.rpc("admin_news_push_reach", {
    p_target: target,
  });
  if (error) throw error;
  const result = (data ?? {}) as Record<string, unknown>;
  return {
    users: Number(result.users ?? 0),
    devices: Number(result.devices ?? 0),
  };
}

/** 캠퍼스런치 소식 알림 즉시 발송 (관리자 JWT). */
export async function invokeNewsPush(
  title: string,
  body: string,
  target: NewsPushTarget = "all",
): Promise<{ ok: boolean; sent: number; failed: number; skipped?: string }> {
  const { data: sessionData } = await supabase.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) {
    throw new Error("로그인이 만료됐어요. 다시 로그인해 주세요.");
  }

  const baseUrl = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.replace(
    /\/$/,
    "",
  );
  const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
  if (!baseUrl || !anonKey) {
    throw new Error("Supabase URL/anon key가 없어요.");
  }

  const res = await fetch(`${baseUrl}/functions/v1/send-news-push`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      apikey: anonKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ title, body, target }),
  });

  const text = await res.text();
  let parsed: unknown = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }

  if (!res.ok) {
    const msg =
      parsed &&
      typeof parsed === "object" &&
      parsed !== null &&
      "error" in parsed
        ? String((parsed as { error: unknown }).error)
        : text || res.statusText;
    throw new Error(`${res.status}: ${msg}`);
  }
  const result = (parsed ?? {}) as Record<string, unknown>;
  return {
    ok: Boolean(result.ok),
    sent: Number(result.sent ?? 0),
    failed: Number(result.failed ?? 0),
    skipped: typeof result.skipped === "string" ? result.skipped : undefined,
  };
}

export async function fetchScheduledNewsPush(): Promise<ScheduledNewsPush[]> {
  const { data, error } = await supabase.rpc("admin_list_scheduled_news_push");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseScheduledNewsPush(row as Record<string, unknown>));
}

export async function createScheduledNewsPush(
  title: string,
  body: string,
  scheduledAt: Date,
  target: NewsPushTarget = "all",
): Promise<ScheduledNewsPush> {
  const { data, error } = await supabase.rpc("admin_create_scheduled_news_push", {
    p_title: title,
    p_body: body,
    p_scheduled_at: scheduledAt.toISOString(),
    p_target: target,
  });
  if (error) throw error;
  return parseScheduledNewsPush(data as Record<string, unknown>);
}

export async function cancelScheduledNewsPush(id: string): Promise<void> {
  const { error } = await supabase.rpc("admin_cancel_scheduled_news_push", {
    p_id: id,
  });
  if (error) throw error;
}

