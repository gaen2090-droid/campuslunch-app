/// 카카오 로컬 검색 + Google Places 영업시간·사진 보강
const CAMPUS_BIAS = "중앙대학교";

export interface PlaceSearchResult {
  placeId: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  phone?: string;
  placeUrl?: string;
}

export interface PlaceDetails extends PlaceSearchResult {
  photoUrl: string | null;
  hours: string;
  hoursDisplay: string;
  hoursPeriods: Record<string, unknown>[];
  googlePlaceId?: string;
}

function restKey(): string {
  return import.meta.env.VITE_KAKAO_REST_API_KEY ?? "";
}

function googleKey(): string {
  return import.meta.env.VITE_GOOGLE_MAPS_API_KEY ?? "";
}

export function hasGoogleKey(): boolean {
  return googleKey().length > 0;
}

async function googlePlacesJson(
  endpoint: "textsearch" | "details",
  params: Record<string, string>,
): Promise<unknown> {
  const qs = new URLSearchParams(params);
  let res: Response;
  try {
    res = await fetch(`/api/google/${endpoint}?${qs}`);
  } catch (e) {
    if (e instanceof TypeError && e.message === "Failed to fetch") {
      throw new Error(
        "Google Places 연결 실패. Vercel에 GOOGLE_MAPS_API_KEY(또는 VITE_GOOGLE_MAPS_API_KEY)를 설정했는지 확인해주세요.",
      );
    }
    throw e;
  }
  if (!res.ok) {
    let detail = "";
    try {
      const err = (await res.json()) as { error?: string };
      detail = err.error ?? "";
    } catch {
      /* ignore */
    }
    throw new Error(
      detail
        ? `Google Places 오류 (${res.status}): ${detail}`
        : `Google Places 오류 (${res.status})`,
    );
  }
  return res.json();
}

function jsKey(): string {
  return import.meta.env.VITE_KAKAO_JAVASCRIPT_KEY ?? "";
}

export function hasKakaoKey(): boolean {
  return restKey().length > 0;
}

function kakaoHeaders(): HeadersInit {
  return { Authorization: `KakaoAK ${restKey()}` };
}

export async function searchPlaces(query: string): Promise<PlaceSearchResult[]> {
  if (query.trim().length < 2) return [];
  if (!hasKakaoKey()) {
    throw new Error("KAKAO_REST_API_KEY가 설정되지 않았어요.");
  }

  const params = new URLSearchParams({
    query: `${query.trim()} ${CAMPUS_BIAS}`,
    x: "126.95707",
    y: "37.50699",
    radius: "3000",
    sort: "distance",
    size: "15",
  });

  const res = await fetch(
    `https://dapi.kakao.com/v2/local/search/keyword.json?${params}`,
    { headers: kakaoHeaders() },
  );
  if (!res.ok) {
    let detail = "";
    try {
      const err = (await res.json()) as { message?: string };
      detail = err.message ?? "";
    } catch {
      /* ignore */
    }
    throw new Error(
      detail
        ? `장소 검색 실패 (${res.status}): ${detail}`
        : `장소 검색 실패 (${res.status})`,
    );
  }

  const data = (await res.json()) as {
    documents?: Array<Record<string, string>>;
  };

  return (data.documents ?? []).map((doc) => {
    const road = doc.road_address_name?.trim() ?? "";
    const jibun = doc.address_name?.trim() ?? "";
    return {
      placeId: doc.id ?? "",
      name: doc.place_name ?? "",
      address: road || jibun,
      latitude: Number.parseFloat(doc.y ?? "0"),
      longitude: Number.parseFloat(doc.x ?? "0"),
      phone: doc.phone,
      placeUrl: doc.place_url,
    };
  });
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function to24Hour(timeStr: string, meridiemHint: string): string | null {
  const m = timeStr.match(/(\d{1,2}):(\d{2})/);
  if (!m) return null;
  let hour = Number.parseInt(m[1], 10);
  const minute = m[2];
  const isPm = /오후|PM/i.test(meridiemHint);
  const isAm = /오전|AM/i.test(meridiemHint);
  if (isPm && hour < 12) hour += 12;
  if (isAm && hour === 12) hour = 0;
  return `${pad2(hour)}:${minute}`;
}

function parseGoogleHours(openingHours?: {
  weekday_text?: string[];
  periods?: Array<{
    open?: { day: number; time: string };
    close?: { day: number; time: string };
  }>;
}): { hours: string; hoursDisplay: string; hoursPeriods: Record<string, unknown>[] } {
  const weekday = openingHours?.weekday_text;
  const periods = openingHours?.periods;
  const hoursPeriods: Record<string, unknown>[] = (periods ?? []).map((p) => ({
    open: p.open ? { day: p.open.day, time: p.open.time } : null,
    close: p.close ? { day: p.close.day, time: p.close.time } : null,
  }));

  if (!weekday?.length) {
    return { hours: "11:00 - 21:00", hoursDisplay: "", hoursPeriods };
  }
  const hoursDisplay = weekday.join("\n");
  const first = weekday[0] ?? "";

  if (/24\s*시간|open\s*24\s*hours/i.test(first)) {
    return { hours: "00:00 - 24:00", hoursDisplay, hoursPeriods };
  }

  const todayDay = new Date().getDay();
  const periodTime = (t: string) => `${t.slice(0, 2)}:${t.slice(2)}`;
  const todayPeriods = (periods ?? []).filter((p) => p.open?.day === todayDay);
  let hours = "11:00 - 21:00";
  if (todayPeriods.length) {
    const ranges = todayPeriods
      .map((p) =>
        p.open && p.close
          ? `${periodTime(p.open.time)} - ${periodTime(p.close.time)}`
          : null,
      )
      .filter((r): r is string => r != null);
    if (ranges.length) hours = ranges.join(", ");
  } else {
    const matches = [...first.matchAll(/(오전|오후|AM|PM)?\s*(\d{1,2}:\d{2})/gi)];
    if (matches.length >= 2) {
      const ranges: string[] = [];
      let lastMeridiem = "";
      for (let i = 0; i + 1 < matches.length; i += 2) {
        const startHint = matches[i][1] ?? lastMeridiem;
        const endHint = matches[i + 1][1] ?? startHint;
        lastMeridiem = endHint;
        const start = to24Hour(matches[i][2], startHint);
        const end = to24Hour(matches[i + 1][2], endHint);
        if (start && end) ranges.push(`${start} - ${end}`);
      }
      if (ranges.length) hours = ranges.join(", ");
    }
  }
  return { hours, hoursDisplay, hoursPeriods };
}

async function findGooglePlaceId(item: PlaceSearchResult): Promise<string | null> {
  if (!hasGoogleKey()) return null;

  const q = `${item.name} ${item.address} ${CAMPUS_BIAS}`.trim();
  const data = (await googlePlacesJson("textsearch", {
    query: q,
    language: "ko",
    region: "kr",
    location: `${item.latitude},${item.longitude}`,
    radius: "500",
  })) as {
    status?: string;
    results?: Array<{
      place_id?: string;
      geometry?: { location?: { lat?: number; lng?: number } };
    }>;
  };
  if (data.status !== "OK" || !data.results?.length) return null;

  let bestId: string | null = null;
  let bestDist = Infinity;
  for (const r of data.results) {
    const lat = r.geometry?.location?.lat;
    const lng = r.geometry?.location?.lng;
    if (lat == null || lng == null || !r.place_id) continue;
    const d = haversine(item.latitude, item.longitude, lat, lng);
    if (d < bestDist) {
      bestDist = d;
      bestId = r.place_id;
    }
  }
  return bestId;
}

async function fetchGoogleEnrichment(placeId: string): Promise<{
  photoUrl: string | null;
  hours: string;
  hoursDisplay: string;
  hoursPeriods: Record<string, unknown>[];
} | null> {
  if (!hasGoogleKey()) return null;

  const data = (await googlePlacesJson("details", {
    place_id: placeId,
    language: "ko",
    fields: "opening_hours,photos",
  })) as {
    status?: string;
    result?: {
      opening_hours?: Parameters<typeof parseGoogleHours>[0];
      photos?: Array<{ photo_reference?: string }>;
    };
  };
  if (data.status !== "OK" || !data.result) return null;

  const bh = parseGoogleHours(data.result.opening_hours);
  let photoUrl: string | null = null;
  const ref = data.result.photos?.[0]?.photo_reference;
  if (ref) {
    photoUrl = `/api/google/photo?maxwidth=800&photo_reference=${encodeURIComponent(ref)}`;
  }
  return { photoUrl, ...bh };
}

function haversine(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const r = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return r * 2 * Math.asin(Math.sqrt(a));
}

export async function enrichPlaceDetails(
  item: PlaceSearchResult,
): Promise<PlaceDetails> {
  const base: PlaceDetails = {
    ...item,
    photoUrl: null,
    hours: "11:00 - 21:00",
    hoursDisplay: "",
    hoursPeriods: [],
  };

  if (!hasGoogleKey()) return base;

  try {
    const googlePlaceId = await findGooglePlaceId(item);
    if (!googlePlaceId) return base;

    const enrichment = await fetchGoogleEnrichment(googlePlaceId);
    if (!enrichment) {
      return { ...base, googlePlaceId };
    }

    return {
      ...base,
      googlePlaceId,
      photoUrl: enrichment.photoUrl,
      hours: enrichment.hours,
      hoursDisplay: enrichment.hoursDisplay,
      hoursPeriods: enrichment.hoursPeriods,
    };
  } catch (e) {
    console.warn("[places] Google enrichment skipped:", e);
    return base;
  }
}

export function kakaoMapEmbedUrl(lat: number, lng: number): string | null {
  const key = jsKey();
  if (!key) return null;
  return `https://map.kakao.com/link/map/${lat},${lng}`;
}
