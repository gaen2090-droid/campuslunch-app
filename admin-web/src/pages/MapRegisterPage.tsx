import { useEffect, useRef, useState } from "react";
import { errorMessage } from "../lib/errors";
import {
  AREAS,
  CATEGORIES,
  findRestaurantIdByKakaoPlaceId,
  insertRestaurant,
  persistGooglePhoto,
} from "../lib/adminApi";
import {
  enrichPlaceDetails,
  hasKakaoKey,
  kakaoMapEmbedUrl,
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
  const [crowdEnabled, setCrowdEnabled] = useState(true);
  const [loading, setLoading] = useState(false);
  const [registering, setRegistering] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [registered, setRegistered] = useState(false);
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
        setError(errorMessage(e));
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
      const details = await enrichPlaceDetails(item);
      setSelected(details);
      setResults([]);
      setQuery(details.name);
    } catch (e) {
      setError(errorMessage(e));
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
      const existing = await findRestaurantIdByKakaoPlaceId(selected.placeId);
      if (existing) {
        setError("등록에 실패했어요. 이미 등록된 가게이거나 권한 문제일 수 있어요.");
        return;
      }
      const imageUrl = selected.photoUrl
        ? (await persistGooglePhoto(selected.photoUrl)) ?? ""
        : "";
      await insertRestaurant({
        name: selected.name,
        address: selected.address,
        latitude: selected.latitude,
        longitude: selected.longitude,
        category,
        area,
        image_url: imageUrl,
        hours: selected.hours,
        hours_display: selected.hoursDisplay,
        hours_periods: selected.hoursPeriods,
        kakao_place_id: selected.placeId,
        google_place_id: selected.googlePlaceId,
        crowd_enabled: crowdEnabled,
      });
      setRegistered(true);
      onReload();
      setSelected(null);
      setQuery("");
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setRegistering(false);
    }
  }

  const mapLink = selected
    ? kakaoMapEmbedUrl(selected.latitude, selected.longitude)
    : null;

  if (!hasKakaoKey()) {
    return (
      <div className="alert">
        카카오 REST API 키가 필요합니다.{" "}
        <code>VITE_KAKAO_REST_API_KEY</code>를 설정해주세요.
      </div>
    );
  }

  return (
    <div className="page">
      <div className="section-head">
        <h2>지도에서 가게 등록</h2>
        <p className="muted sm">
          장소 검색은 카카오맵, 영업시간·사진은 Google Places에서 자동으로
          가져옵니다.
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

      <label className="checkbox-row">
        <input
          type="checkbox"
          checked={crowdEnabled}
          onChange={(e) => setCrowdEnabled(e.target.checked)}
        />
        <span>
          제보 대상으로 노출{" "}
          <span className="muted xs">
            (끄면 맛집컬렉션 전용 매장 — 지도/홈에 안 뜨고 혼잡도 제보 기능 없음)
          </span>
        </span>
      </label>

      {mapLink && (
        <p className="muted sm">
          <a href={mapLink} target="_blank" rel="noreferrer">
            카카오맵에서 위치 확인 →
          </a>
        </p>
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

      {registered && (
        <Modal title="가게 등록 완료" onClose={() => setRegistered(false)}>
          <p className="muted sm">
            영업시간·사진은 Google Places에서 자동 수집됩니다. 매칭이 안 되면
            매장 관리에서 수정해주세요.
          </p>
          <p className="muted sm">
            사장님은 앱 → 사장님 인증에서 이 매장을 선택해 인증을 신청할 수
            있어요.
          </p>
        </Modal>
      )}
    </div>
  );
}
