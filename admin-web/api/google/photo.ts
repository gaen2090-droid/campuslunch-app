import type { VercelRequest, VercelResponse } from "@vercel/node";

function googleKey(): string {
  return (
    process.env.GOOGLE_MAPS_API_KEY ??
    process.env.VITE_GOOGLE_MAPS_API_KEY ??
    ""
  );
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const key = googleKey();
  if (!key) {
    return res.status(500).json({ error: "GOOGLE_MAPS_API_KEY not configured" });
  }

  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(req.query)) {
    if (v == null || k === "key") continue;
    params.set(k, Array.isArray(v) ? v[0] : String(v));
  }
  params.set("key", key);

  try {
    const upstream = await fetch(
      `https://maps.googleapis.com/maps/api/place/photo?${params}`,
    );
    if (!upstream.ok) {
      return res.status(upstream.status).json({ error: "Google photo fetch failed" });
    }
    const contentType = upstream.headers.get("content-type") ?? "image/jpeg";
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.setHeader("Content-Type", contentType);
    return res.status(200).send(buffer);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return res.status(502).json({ error: msg });
  }
}
