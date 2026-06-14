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

function parseGoogleHours(
  openingHours?: google.maps.places.PlaceOpeningHours,
): { hours: string; hoursDisplay: string; hoursPeriods: Record<string, unknown>[] } {
  const weekday = openingHours?.weekday_text;
  if (!weekday?.length) {
    return { hours: "11:00 - 21:00", hoursDisplay: "", hoursPeriods: [] };
  }
  const hoursDisplay = weekday.join("\n");
  const first = weekday[0] ?? "";
  const match = first.match(/(\d{1,2}:\d{2}).*?(\d{1,2}:\d{2})/);
  const hours = match ? `${match[1]} - ${match[2]}` : "11:00 - 21:00";
  return { hours, hoursDisplay, hoursPeriods: [] };
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
