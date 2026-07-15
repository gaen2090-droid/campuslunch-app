import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  authorizeRequest,
  getGoogleAccessToken,
  jsonResponse,
  loadServiceAccountFromEnv,
  sendFcmMessage,
} from "../_shared/fcm.ts";

type Cfg = {
  community_fcm_enabled?: boolean;
  community_comment_title_template?: string;
  community_comment_body_template?: string;
};

function formatTemplate(
  template: string,
  vars: Record<string, string>,
): string {
  let out = template;
  for (const [k, v] of Object.entries(vars)) {
    out = out.replaceAll(`{${k}}`, v);
  }
  return out;
}

function extractPayload(body: Record<string, unknown>): {
  event: "comment";
  commentId?: string;
} | null {
  const record = body.record as Record<string, unknown> | undefined;

  // Database webhook: INSERT on community_comments
  if (record && typeof record.id === "string" && body.table === "community_comments") {
    return { event: "comment", commentId: record.id };
  }

  const commentId =
    typeof body.comment_id === "string"
      ? body.comment_id
      : (record && typeof record.id === "string" ? record.id : null);
  if (commentId) return { event: "comment", commentId };
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
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

    const { data: cfgRow } = await supabase.rpc("get_push_notification_config");
    const cfg = (cfgRow ?? {}) as Cfg;
    if (cfg.community_fcm_enabled === false) {
      return jsonResponse({ skipped: true, reason: "community_fcm_disabled" });
    }

    const body = await req.json() as Record<string, unknown>;
    const payload = extractPayload(body);
    if (!payload) {
      return jsonResponse({ error: "invalid payload" }, 400);
    }

    const sa = loadServiceAccountFromEnv();
    const access = await getGoogleAccessToken(sa);
    let sent = 0;
    let failed = 0;
    const invalidTokens: string[] = [];

    if (payload.event === "comment" && payload.commentId) {
      const { data: recipients, error } = await supabase.rpc(
        "list_community_comment_push_recipients",
        { p_comment_id: payload.commentId },
      );
      if (error) throw error;
      const list = (recipients ?? []) as {
        user_id: string;
        token: string;
        post_id: string;
        comment_preview: string;
        nickname: string;
      }[];

      const titleTpl = cfg.community_comment_title_template ??
        "{nickname}님이 댓글을 남겼어요";
      const bodyTpl = cfg.community_comment_body_template ?? "{content}";

      for (const row of list) {
        const title = formatTemplate(titleTpl, {
          nickname: row.nickname,
          content: row.comment_preview,
          post_preview: row.comment_preview,
        });
        const text = formatTemplate(bodyTpl, {
          nickname: row.nickname,
          content: row.comment_preview,
          post_preview: row.comment_preview,
        });
        const result = await sendFcmMessage(sa, access, {
          token: row.token,
          title,
          body: text,
          data: {
            type: "community_comment",
            post_id: String(row.post_id),
            comment_id: payload.commentId,
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
    }

    if (invalidTokens.length > 0) {
      await supabase.from("user_push_tokens").delete().in(
        "token",
        invalidTokens,
      );
    }

    return jsonResponse({
      ok: true,
      event: payload.event,
      sent,
      failed,
    });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
