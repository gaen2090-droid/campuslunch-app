import type { Plugin } from "vite";

/** 로컬 `npm run dev`에서 /api/google/* → Google Places (CORS 회피) */
export function googlePlacesApiPlugin(apiKey: string): Plugin {
  return {
    name: "google-places-api",
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const rawUrl = req.url ?? "";
        if (!rawUrl.startsWith("/api/google/")) return next();

        const parsed = new URL(rawUrl, "http://localhost");
        const endpoint = parsed.pathname.replace("/api/google/", "");
        if (endpoint !== "textsearch" && endpoint !== "details" && endpoint !== "photo") {
          return next();
        }

        if (!apiKey) {
          res.statusCode = 500;
          res.setHeader("Content-Type", "application/json");
          res.end(JSON.stringify({ error: "GOOGLE_MAPS_API_KEY not set" }));
          return;
        }

        const params = parsed.searchParams;
        params.delete("key");
        params.set("key", apiKey);

        try {
          if (endpoint === "photo") {
            const upstream = await fetch(
              `https://maps.googleapis.com/maps/api/place/photo?${params}`,
            );
            const arrayBuffer = await upstream.arrayBuffer();
            res.statusCode = upstream.status;
            res.setHeader(
              "Content-Type",
              upstream.headers.get("content-type") ?? "image/jpeg",
            );
            res.end(Buffer.from(arrayBuffer));
            return;
          }

          const upstream = await fetch(
            `https://maps.googleapis.com/maps/api/place/${endpoint}/json?${params}`,
          );
          const body = await upstream.text();
          res.statusCode = upstream.status;
          res.setHeader("Content-Type", "application/json");
          res.end(body);
        } catch (e) {
          res.statusCode = 502;
          res.setHeader("Content-Type", "application/json");
          res.end(
            JSON.stringify({
              error: e instanceof Error ? e.message : String(e),
            }),
          );
        }
      });
    },
  };
}
