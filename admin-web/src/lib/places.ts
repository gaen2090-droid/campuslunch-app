export interface PlaceSearchResult {
  placeId: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
}

export interface PlaceDetails extends PlaceSearchResult {
  photoUrl: string | null;
  hours: string;
  hoursDisplay: string;
  hoursPeriods: Record<string, unknown>[];
}


function mapsKey(): string {
  return import.meta.env.VITE_GOOGLE_MAPS_API_KEY ?? "";
}

let loadPromise: Promise<void> | null = null;

function loadMapsScript(): Promise<void> {
  const key = mapsKey();
  if (!key) return Promise.reject(new Error("Google Maps API 키가 없습니다."));
  if (window.google?.maps?.places) return Promise.resolve();
  if (loadPromise) return loadPromise;

  loadPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector(
      'script[data-cl-maps="1"]',
    ) as HTMLScriptElement | null;
    if (existing) {
      existing.addEventListener("load", () => resolve());
      existing.addEventListener("error", () =>
        reject(new Error("Maps script load failed")),
      );
      return;
    }
    const script = document.createElement("script");
    script.dataset.clMaps = "1";
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(key)}&libraries=places&language=ko`;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Maps script load failed"));
    document.head.appendChild(script);
  });
  return loadPromise;
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

// "오전 8:00" / "오후 10:30" / "AM 8:00" / "8:00 PM" 등을 24시간제 "HH:mm"으로 변환
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

function parseGoogleHours(
  openingHours?: google.maps.places.PlaceOpeningHours,
): { hours: string; hoursDisplay: string; hoursPeriods: Record<string, unknown>[] } {
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

  // Google periods의 "HHmm" 시각은 AM/PM 표기 모호성이 없어 가장 신뢰도가 높음
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
    // periods가 없으면 weekday_text 첫 줄에서 시간 추출 (브레이크타임 등 여러 구간 지원, AM/PM 마커는 직전 값 상속)
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

export async function searchPlaces(query: string): Promise<PlaceSearchResult[]> {
  if (query.trim().length < 2) return [];
  await loadMapsScript();

  return new Promise((resolve) => {
    const service = new google.maps.places.PlacesService(
      document.createElement("div"),
    );
    service.textSearch(
      {
        query: `${query.trim()} 중앙대학교`,
        region: "kr",
      },
      (results, status) => {
        if (
          status !== google.maps.places.PlacesServiceStatus.OK ||
          !results?.length
        ) {
          resolve([]);
          return;
        }
        resolve(
          results.map((r) => ({
            placeId: r.place_id ?? "",
            name: r.name ?? "",
            address: r.formatted_address ?? r.vicinity ?? "",
            latitude: r.geometry?.location?.lat() ?? 0,
            longitude: r.geometry?.location?.lng() ?? 0,
          })),
        );
      },
    );
  });
}

export async function getPlaceDetails(
  placeId: string,
): Promise<PlaceDetails | null> {
  await loadMapsScript();

  return new Promise((resolve) => {
    const service = new google.maps.places.PlacesService(
      document.createElement("div"),
    );
    service.getDetails(
      {
        placeId,
        fields: [
          "place_id",
          "name",
          "formatted_address",
          "geometry",
          "opening_hours",
          "photos",
        ],
      },
      (result, status) => {
        if (
          status !== google.maps.places.PlacesServiceStatus.OK ||
          !result
        ) {
          resolve(null);
          return;
        }
        const key = mapsKey();
        let photoUrl: string | null = null;
        const photos = result.photos;
        if (photos?.length && key) {
          photoUrl = photos[0].getUrl({ maxWidth: 800 });
        }
        const bh = parseGoogleHours(result.opening_hours ?? undefined);
        resolve({
          placeId: result.place_id ?? placeId,
          name: result.name ?? "",
          address: result.formatted_address ?? "",
          latitude: result.geometry?.location?.lat() ?? 0,
          longitude: result.geometry?.location?.lng() ?? 0,
          photoUrl,
          hours: bh.hours,
          hoursDisplay: bh.hoursDisplay,
          hoursPeriods: bh.hoursPeriods,
        });
      },
    );
  });
}

export function mapsEmbedUrl(lat: number, lng: number): string | null {
  const key = mapsKey();
  if (!key) return null;
  return `https://www.google.com/maps/embed/v1/view?key=${encodeURIComponent(key)}&center=${lat},${lng}&zoom=17`;
}

export function hasMapsKey(): boolean {
  return mapsKey().length > 0;
}
