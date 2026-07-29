/** FCM HTTP v1 helpers for Supabase Edge Functions (Deno). */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

function b64url(data: ArrayBuffer | string): string {
  const bytes =
    typeof data === "string"
      ? new TextEncoder().encode(data)
      : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function loadServiceAccountFromEnv(): ServiceAccount {
  const json = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (json) {
    const parsed = JSON.parse(json) as ServiceAccount;
    return {
      ...parsed,
      private_key: parsed.private_key.replace(/\\n/g, "\n"),
    };
  }
  const project_id = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
  const client_email = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
  const private_key = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(
    /\\n/g,
    "\n",
  );
  if (!project_id || !client_email || !private_key) {
    throw new Error(
      "Firebase service account secrets missing (FIREBASE_SERVICE_ACCOUNT_JSON or PROJECT_ID/CLIENT_EMAIL/PRIVATE_KEY)",
    );
  }
  return { project_id, client_email, private_key };
}

export async function getGoogleAccessToken(
  sa: ServiceAccount,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64url(JSON.stringify(header))}.${
    b64url(JSON.stringify(claim))
  }`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`oauth token failed: ${res.status} ${await res.text()}`);
  }
  const body = await res.json() as { access_token: string };
  return body.access_token;
}

export type FcmPayload = {
  token: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
  /** data-only (시스템 알림 없음) */
  dataOnly?: boolean;
};

export async function sendFcmMessage(
  sa: ServiceAccount,
  accessToken: string,
  msg: FcmPayload,
): Promise<{ ok: boolean; status: number; body: string }> {
  const message: Record<string, unknown> = {
    token: msg.token,
    data: msg.data ?? {},
    android: { priority: "HIGH" },
    apns: {
      headers: { "apns-priority": msg.dataOnly ? "5" : "10" },
      payload: {
        aps: msg.dataOnly
          ? { "content-available": 1 }
          : { sound: "default" },
      },
    },
  };
  if (!msg.dataOnly) {
    message.notification = {
      title: msg.title ?? "",
      body: msg.body ?? "",
    };
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    },
  );
  const text = await res.text();
  return { ok: res.ok, status: res.status, body: text };
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function corsPreflightResponse(): Response {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

/** cron secret 또는 어드민 JWT */
export async function authorizeRequest(req: Request): Promise<boolean> {
  const auth = req.headers.get("Authorization") ?? "";
  const expected = Deno.env.get("EDGE_PUSH_SECRET") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (expected && auth === `Bearer ${expected}`) return true;
  if (serviceKey && auth === `Bearer ${serviceKey}`) return true;

  if (!auth.startsWith("Bearer ")) return false;
  const jwt = auth.slice("Bearer ".length);
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon || !serviceKey) return false;

  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) return false;

  const adminClient = createClient(url, serviceKey);
  const { data: row } = await adminClient
    .from("users")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle();
  return row?.role === "admin";
}
