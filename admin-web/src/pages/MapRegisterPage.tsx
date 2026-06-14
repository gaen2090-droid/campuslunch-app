import { useEffect, useRef, useState } from "react";
import {
  AREAS,
  CATEGORIES,
  findRestaurantIdByGooglePlaceId,
  insertRestaurant,
} from "../lib/adminApi";
import {
  getPlaceDetails,
  hasMapsKey,
  mapsEmbedUrl,
  searchPlaces,
  type PlaceDetails,
  type PlaceSearchResult,
} from "../lib/places";
import { Modal } from "../components/Modal";

interface Props {
  onReload: () => void;
}

export function MapRegisterPage({ onReload }: Props) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<PlaceSearchResult[]>([]);
  const [selected, setSelected] = useState<PlaceDetails | null>(null);
  const [area, setArea] = useState<string>(AREAS[0]);
  const [category, setCategory] = useState<string>(CATEGORIES[0]);
  const [loading, setLoading] = useState(false);
  const [registering, setRegistering] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ownerCode, setOwnerCode] = useState<string | null>(null);
  const debounceRef = useRef<number | null>(null);

  useEffect(() => {
    if (debounceRef.current) window.clearTimeout(debounceRef.current);
    if (query.trim().length < 2) {
      setResults([]);
      return;
    }
    debounceRef.current = window.setTimeout(async () => {
      setLoading(true);
      setError(null);
      try {
        setResults(await searchPlaces(query));
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
        setResults([]);
      } finally {
        setLoading(false);
      }
    }, 400);
    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
    };
  }, [query]);

  async function pickPlace(item: PlaceSearchResult) {
    setLoading(true);
    setError(null);
    try {
      const details = await getPlaceDetails(item.placeId);
      setSelected(details);
      setResults([]);
      setQuery(details?.name ?? item.name);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  async function register() {
    if (!selected) {
      setError("지도에서 가게를 먼저 선택해주세요.");
      return;
    }
    setRegistering(true);
    setError(null);
    try {
      const existing = await findRestaurantIdByGooglePlaceId(selected.placeId);
      if (existing) {
        setError("등록에 실패했어요. 이미 등록된 가게이거나 권한 문제일 수 있어요.");
        return;
      }
      const code = await insertRestaurant({
        name: selected.name,
        address: selected.address,
        latitude: selected.latitude,
        longitude: selected.longitude,
        category,
        area,
        image_url: selected.photoUrl ?? "",
        hours: selected.hours,
        hours_display: selected.hoursDisplay,
        hours_periods: selected.hoursPeriods,
        google_place_id: selected.placeId,
      });
      setOwnerCode(code);
      onReload();
      setSelected(null);
      setQuery("");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setRegistering(false);
    }
  }

  const embed = selected
    ? mapsEmbedUrl(selected.latitude, selected.longitude)
    : null;

  if (!hasMapsKey()) {
    return (
      <div className="alert">
        Google Maps API 키가 필요합니다.{" "}
        <code>VITE_GOOGLE_MAPS_API_KEY</code>를 설정해주세요.
      </div>
    );
  }

  return (
    <div className="page">
      <div className="section-head">
        <h2>지도에서 가게 등록</h2>
        <p className="muted sm">
          중앙대 주변 장소를 검색한 뒤 «가게 신규 등록»을 누르면 6자리 인증번호가
          발급됩니다.
        </p>
      </div>

      <input
        className="search-input"
        placeholder="가게명 검색 (예: 양셰프)"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      {loading && <p className="muted sm">검색 중…</p>}

      {results.length > 0 && (
        <ul className="search-results">
          {results.map((item) => (
            <li key={item.placeId}>
              <button type="button" onClick={() => pickPlace(item)}>
                <strong>{item.name}</strong>
                <span className="muted sm">{item.address}</span>
              </button>
            </li>
          ))}
        </ul>
      )}

      <div className="form-row">
        <label className="field">
          <span className="field-label">구역</span>
          <select value={area} onChange={(e) => setArea(e.target.value)}>
            {AREAS.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span className="field-label">카테고리</span>
          <select value={category} onChange={(e) => setCategory(e.target.value)}>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </label>
      </div>

      {embed && (
        <iframe
          title="선택한 위치"
          className="map-embed"
          src={embed}
          loading="lazy"
          referrerPolicy="no-referrer-when-downgrade"
        />
      )}

      {selected && (
        <p className="muted sm">{selected.address}</p>
      )}

      {error && <div className="alert">{error}</div>}

      <button
        type="button"
        className="btn primary block"
        disabled={registering || !selected}
        onClick={register}
      >
        {registering ? "등록 중…" : "가게 신규 등록"}
      </button>

      {ownerCode && (
        <Modal title="가게 등록 완료" onClose={() => setOwnerCode(null)}>
          <p className="owner-code-lg">{ownerCode}</p>
          <p className="muted sm">
            사장님 앱 → 인증 화면에서 위 번호를 입력하면 혼잡도를 관리할 수
            있어요.
          </p>
        </Modal>
      )}
    </div>
  );
}
