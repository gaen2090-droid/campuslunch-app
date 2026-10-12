import { useEffect, useState } from "react";
import {
  AREAS,
  CATEGORIES,
  insertRestaurant,
  updateRestaurant,
  uploadRestaurantImage,
} from "../lib/adminApi";
import type { AdminRestaurant, MenuItem, RestaurantFormData } from "../types/restaurant";
import { errorMessage } from "../lib/errors";
import { geocodeAddress, type GeocodeCandidate } from "../lib/places";
import { Modal } from "./Modal";

interface Props {
  mode: "add" | "edit";
  restaurant?: AdminRestaurant;
  /** 탭(제보 O / 컬렉션 X)에서 고정할 때 */
  defaultCrowdEnabled?: boolean;
  lockCrowdEnabled?: boolean;
  onClose: () => void;
  onSaved: () => void;
}

interface TimeRange {
  from: string;
  to: string;
}

const ALWAYS_OPEN_HOURS = "00:00 - 24:00";
/** 대표메뉴는 매장당 최대 2개까지 지정할 수 있다. */
const MAX_SIGNATURE = 2;

function pad2(s: string): string {
  const [h, m] = s.split(":");
  return `${h.padStart(2, "0")}:${m}`;
}

function isAlwaysOpen(hours: string): boolean {
  return hours.trim() === ALWAYS_OPEN_HOURS;
}

function parseHours(hours: string): TimeRange[] {
  const parts = hours.split(",").map((s) => s.trim()).filter(Boolean);
  if (!parts.length) return [{ from: "11:00", to: "21:00" }];
  return parts.map((part) => {
    const m = part.match(/(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})/);
    if (m) return { from: pad2(m[1]), to: pad2(m[2]) };
    return { from: "11:00", to: "21:00" };
  });
}

export function RestaurantFormModal({
  mode,
  restaurant,
  defaultCrowdEnabled,
  lockCrowdEnabled = false,
  onClose,
  onSaved,
}: Props) {
  const [name, setName] = useState(restaurant?.name ?? "");
  const [area, setArea] = useState(restaurant?.area ?? AREAS[0]);
  // 위치: 주소로 좌표를 찾거나 위도/경도를 직접 입력한다. 0/0이면 "위치 없음".
  const [addressText, setAddressText] = useState(restaurant?.address ?? "");
  const [latitude, setLatitude] = useState<number>(restaurant?.latitude ?? 0);
  const [longitude, setLongitude] = useState<number>(restaurant?.longitude ?? 0);
  const [candidates, setCandidates] = useState<GeocodeCandidate[]>([]);
  const [locating, setLocating] = useState(false);
  const [locationMsg, setLocationMsg] = useState("");
  const [category, setCategory] = useState(
    restaurant?.category ?? CATEGORIES[0],
  );
  const [alwaysOpen, setAlwaysOpen] = useState(
    isAlwaysOpen(restaurant?.hours ?? ""),
  );
  const [times, setTimes] = useState<TimeRange[]>(() =>
    isAlwaysOpen(restaurant?.hours ?? "")
      ? [{ from: "11:00", to: "21:00" }]
      : parseHours(restaurant?.hours ?? "11:00 - 21:00"),
  );
  const [menu, setMenu] = useState<MenuItem[]>(
    restaurant?.menu.length ? restaurant.menu : [{ name: "", price: 0 }],
  );
  // 대표메뉴는 이름이 아니라 행 인덱스로 추적한다 — 같은 저장 안에서 이름을 바꿔도
  // 연결이 끊기지 않게. 저장 시점에 이름으로 변환해 signature_menu 키에 쓴다.
  const [signatureIdxs, setSignatureIdxs] = useState<number[]>(() => {
    if (!restaurant) return [];
    const out: number[] = [];
    for (const sig of restaurant.signatureMenus ?? []) {
      const idx = restaurant.menu.findIndex((m) => m.name.trim() === sig.trim());
      if (idx >= 0 && !out.includes(idx)) out.push(idx);
    }
    return out.slice(0, MAX_SIGNATURE);
  });
  const [imageSourceLabel, setImageSourceLabel] = useState(
    restaurant?.imageSourceLabel || "Google Maps",
  );
  const [closedDays, setClosedDays] = useState<number[]>(
    restaurant?.closedDays ?? [],
  );
  const [closedOnHolidays, setClosedOnHolidays] = useState(
    restaurant?.closedOnHolidays ?? false,
  );
  const [soloFriendly, setSoloFriendly] = useState(
    restaurant?.soloFriendly ?? false,
  );
  const [dateFriendly, setDateFriendly] = useState(
    restaurant?.dateFriendly ?? false,
  );
  // 영업시간을 실제로 건드렸을 때만 hours를 저장한다. 저장 시 hours가 오면
  // hours_periods(구글 요일별 캐시)를 지우므로, 혼밥/대표메뉴만 바꾸는 저장이
  // 영업 여부 판정을 깨뜨리지 않게 막는다.
  const [hoursDirty, setHoursDirty] = useState(false);
  const [crowdEnabled, setCrowdEnabled] = useState(
    restaurant?.crowdEnabled ?? defaultCrowdEnabled ?? true,
  );
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [preview, setPreview] = useState(restaurant?.imageUrl ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!imageFile) return;
    const url = URL.createObjectURL(imageFile);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [imageFile]);

  async function findLocation() {
    setLocating(true);
    setLocationMsg("");
    setCandidates([]);
    try {
      const found = await geocodeAddress(addressText);
      if (found.length === 0) {
        setLocationMsg("주소를 찾지 못했어요. 도로명/지번 주소를 더 자세히 입력해 주세요.");
      } else if (found.length === 1) {
        applyCandidate(found[0]);
      } else {
        setCandidates(found);
        setLocationMsg("아래에서 맞는 위치를 선택해 주세요.");
      }
    } catch (err) {
      setLocationMsg(errorMessage(err));
    } finally {
      setLocating(false);
    }
  }

  function applyCandidate(c: GeocodeCandidate) {
    setLatitude(c.latitude);
    setLongitude(c.longitude);
    setAddressText(c.address);
    setCandidates([]);
    setLocationMsg("위치를 설정했어요. 저장하면 반영돼요.");
  }

  const hasLocation = Math.abs(latitude) > 0.0001 && Math.abs(longitude) > 0.0001;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) {
      setError("매장명을 입력해주세요.");
      return;
    }
    if (
      hasLocation &&
      (latitude < 33 || latitude > 39 || longitude < 124 || longitude > 132)
    ) {
      setError("위도/경도가 한국 범위를 벗어났어요. 위도·경도 순서를 확인해 주세요.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      let imageUrl: string | undefined;
      if (imageFile) {
        imageUrl = await uploadRestaurantImage(imageFile);
      }
      const hours = alwaysOpen
        ? ALWAYS_OPEN_HOURS
        : times.map((t) => `${t.from} - ${t.to}`).join(", ");
      // 최대 가격은 최소 가격보다 클 때만 범위로 저장한다 (아니면 단일 가격).
      const validMenu = menu
        .filter((m) => m.name.trim())
        .map(({ price_max, ...m }) =>
          price_max && price_max > m.price ? { ...m, price_max } : m,
        );
      const signatureNames = signatureIdxs
        .map((i) => menu[i]?.name.trim() ?? "")
        .filter((n) => n.length > 0);
      const data: RestaurantFormData = {
        name: name.trim(),
        area,
        category,
        address: addressText.trim() || area,
        latitude: hasLocation ? latitude : 0,
        longitude: hasLocation ? longitude : 0,
        hours,
        menu: validMenu,
        crowd_enabled: crowdEnabled,
        image_source_label: imageSourceLabel,
        closed_days: closedDays,
        closed_on_holidays: closedOnHolidays,
        solo_friendly: soloFriendly,
        date_friendly: dateFriendly,
        signature_menus: signatureNames,
        ...(imageUrl ? { image_url: imageUrl } : {}),
      };
      if (mode === "add") {
        await insertRestaurant(data);
      } else if (restaurant) {
        const { hours: _hours, ...withoutHours } = data;
        await updateRestaurant(
          restaurant.id,
          hoursDirty ? data : withoutHours,
        );
      }
      onSaved();
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal
      title={mode === "add" ? "매장 추가" : "매장 수정"}
      onClose={onClose}
      wide
    >
      <form className="form-grid" onSubmit={submit}>
        <label className="field">
          <span className="field-label">이미지</span>
          <div className="image-picker">
            {preview ? (
              <img src={preview} alt="" className="preview-img" />
            ) : (
              <span className="muted">이미지 없음</span>
            )}
            <input
              type="file"
              accept="image/*"
              onChange={(e) => setImageFile(e.target.files?.[0] ?? null)}
            />
          </div>
        </label>

        <label className="field">
          <span className="field-label">
            이미지 출처{" "}
            <span className="muted xs">
              (앱 상세 화면 사진 우측 하단에 &quot;출처: ○○&quot;로 표시 · 기본값 Google Maps ·
              사장님이 직접 올린 사진은 &quot;사장님&quot;으로 자동 표시)
            </span>
          </span>
          <input
            value={imageSourceLabel}
            maxLength={20}
            placeholder="Google Maps"
            onChange={(e) => setImageSourceLabel(e.target.value)}
          />
        </label>

        <label className="field">
          <span className="field-label">매장명 *</span>
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </label>

        <div className="field">
          <span className="field-label">
            위치{" "}
            <span className="muted xs">
              (주소만 입력해도 돼요 · 위치가 없으면 지도·거리 기능에서 빠져요)
            </span>
          </span>
          <div className="menu-row">
            <input
              placeholder="도로명 또는 지번 주소 (예: 서울 동작구 흑석로 84)"
              value={addressText}
              onChange={(e) => setAddressText(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  void findLocation();
                }
              }}
            />
            <button
              type="button"
              className="btn ghost sm"
              disabled={locating || addressText.trim().length < 2}
              onClick={() => void findLocation()}
            >
              {locating ? "찾는 중…" : "위치 찾기"}
            </button>
          </div>
          {candidates.length > 0 && (
            <ul style={{ listStyle: "none", margin: "4px 0", padding: 0, display: "grid", gap: 4 }}>
              {candidates.map((c, i) => (
                <li key={i}>
                  <button
                    type="button"
                    className="btn ghost sm"
                    onClick={() => applyCandidate(c)}
                  >
                    {c.label}
                  </button>
                </li>
              ))}
            </ul>
          )}
          {locationMsg && <p className="muted xs">{locationMsg}</p>}
          <div className="menu-row">
            <input
              type="number"
              step="any"
              placeholder="위도 (예: 37.5070)"
              value={latitude || ""}
              onChange={(e) => setLatitude(Number.parseFloat(e.target.value) || 0)}
            />
            <input
              type="number"
              step="any"
              placeholder="경도 (예: 126.9571)"
              value={longitude || ""}
              onChange={(e) => setLongitude(Number.parseFloat(e.target.value) || 0)}
            />
          </div>
          <p className="muted xs">
            {hasLocation ? (
              <>
                현재 위치: {latitude.toFixed(6)}, {longitude.toFixed(6)} ·{" "}
                <a
                  href={`https://map.kakao.com/link/map/${encodeURIComponent(name || "매장")},${latitude},${longitude}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  카카오맵에서 확인
                </a>
              </>
            ) : (
              "위치 미설정"
            )}
          </p>
        </div>

        {lockCrowdEnabled ? (
          <p className="muted sm">
            {crowdEnabled
              ? "제보 대상(O) 탭에서 추가 · restaurant_report_targets"
              : "컬렉션 전용(X) 탭에서 추가 · restaurant_collection_venues"}
          </p>
        ) : (
          <label className="checkbox-row">
            <input
              type="checkbox"
              checked={crowdEnabled}
              onChange={(e) => setCrowdEnabled(e.target.checked)}
            />
            <span>
              제보 대상으로 노출{" "}
              <span className="muted xs">
                (끄면 맛집컬렉션 전용 매장 — 지도/홈에 안 뜨고 혼잡도 제보 기능
                없음)
              </span>
            </span>
          </label>
        )}

        <label className="checkbox-row">
          <input
            type="checkbox"
            checked={soloFriendly}
            onChange={(e) => setSoloFriendly(e.target.checked)}
          />
          <span>
            혼밥하기 좋은 매장{" "}
            <span className="muted xs">
              (점메추 요정에서 &quot;혼밥&quot; 선택 시 우선 추천돼요)
            </span>
          </span>
        </label>

        <label className="checkbox-row">
          <input
            type="checkbox"
            checked={dateFriendly}
            onChange={(e) => setDateFriendly(e.target.checked)}
          />
          <span>
            밥약하기 좋은 매장{" "}
            <span className="muted xs">
              (점메추 요정에서 &quot;밥약&quot; 선택 시 우선 추천돼요)
            </span>
          </span>
        </label>

        <div className="form-row">
          <label className="field">
            <span className="field-label">지역 *</span>
            <select value={area} onChange={(e) => setArea(e.target.value)}>
              {AREAS.map((a) => (
                <option key={a} value={a}>
                  {a}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span className="field-label">카테고리 *</span>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className="field">
          <span className="field-label">영업시간 *</span>
          <label className="checkbox-row">
            <input
              type="checkbox"
              checked={alwaysOpen}
              onChange={(e) => {
                setAlwaysOpen(e.target.checked);
                setHoursDirty(true);
              }}
            />
            <span>24시간 운영</span>
          </label>
          {!alwaysOpen && times.map((t, i) => (
            <div key={i} className="time-row">
              <input
                type="time"
                value={t.from}
                onChange={(e) => {
                  setHoursDirty(true);
                  setTimes((prev) =>
                    prev.map((row, idx) =>
                      idx === i ? { ...row, from: e.target.value } : row,
                    ),
                  );
                }}
              />
              <span>~</span>
              <input
                type="time"
                value={t.to}
                onChange={(e) => {
                  setHoursDirty(true);
                  setTimes((prev) =>
                    prev.map((row, idx) =>
                      idx === i ? { ...row, to: e.target.value } : row,
                    ),
                  );
                }}
              />
              {times.length > 1 && (
                <button
                  type="button"
                  className="btn ghost sm"
                  onClick={() => {
                    setHoursDirty(true);
                    setTimes((prev) => prev.filter((_, idx) => idx !== i));
                  }}
                >
                  삭제
                </button>
              )}
            </div>
          ))}
          {!alwaysOpen && (
            <button
              type="button"
              className="btn ghost sm"
              onClick={() => {
                setHoursDirty(true);
                setTimes((prev) => [...prev, { from: "11:00", to: "21:00" }]);
              }}
            >
              + 시간 추가
            </button>
          )}
        </div>

        <div className="field">
          <span className="field-label">
            정기 휴무{" "}
            <span className="muted xs">
              (휴무 요일엔 앱에서 "영업안함"으로 보이고, 점메추 요정에서도 빠져요)
            </span>
          </span>
          <div className="menu-row">
            {["월", "화", "수", "목", "금", "토", "일"].map((label, i) => {
              const day = i + 1;
              const on = closedDays.includes(day);
              return (
                <button
                  key={day}
                  type="button"
                  className={`btn sm ${on ? "primary" : "ghost"}`}
                  onClick={() =>
                    setClosedDays((cur) =>
                      cur.includes(day)
                        ? cur.filter((d) => d !== day)
                        : [...cur, day].sort((a, b) => a - b),
                    )
                  }
                >
                  {label}
                </button>
              );
            })}
          </div>
          <label className="checkbox-row">
            <input
              type="checkbox"
              checked={closedOnHolidays}
              onChange={(e) => setClosedOnHolidays(e.target.checked)}
            />
            <span>공휴일 휴무 (대체공휴일 포함)</span>
          </label>
        </div>

        <div className="field">
          <span className="field-label">
            메뉴{" "}
            <span className="muted xs">
              (대표메뉴 {signatureIdxs.length}/{MAX_SIGNATURE})
            </span>
          </span>
          {menu.map((item, i) => (
            <div key={i} className="menu-row">
              <input
                placeholder="메뉴명"
                value={item.name}
                onChange={(e) =>
                  setMenu((prev) =>
                    prev.map((m, idx) =>
                      idx === i ? { ...m, name: e.target.value } : m,
                    ),
                  )
                }
              />
              <input
                type="number"
                placeholder="가격"
                value={item.price || ""}
                onChange={(e) =>
                  setMenu((prev) =>
                    prev.map((m, idx) =>
                      idx === i
                        ? {
                            ...m,
                            price: Number.parseInt(e.target.value, 10) || 0,
                          }
                        : m,
                    ),
                  )
                }
              />
              <span className="muted xs">~</span>
              <input
                type="number"
                placeholder="최대 (선택)"
                title="가격이 범위일 때만 입력하세요. 예: 6000 ~ 9000원"
                value={item.price_max || ""}
                onChange={(e) =>
                  setMenu((prev) =>
                    prev.map((m, idx) =>
                      idx === i
                        ? {
                            ...m,
                            price_max:
                              Number.parseInt(e.target.value, 10) || undefined,
                          }
                        : m,
                    ),
                  )
                }
              />
              <button
                type="button"
                className={`btn sm ${signatureIdxs.includes(i) ? "primary" : "ghost"}`}
                disabled={
                  !item.name.trim() ||
                  (!signatureIdxs.includes(i) &&
                    signatureIdxs.length >= MAX_SIGNATURE)
                }
                title={
                  !signatureIdxs.includes(i) &&
                  signatureIdxs.length >= MAX_SIGNATURE
                    ? "대표메뉴는 최대 2개까지예요. 다른 대표를 먼저 해제해 주세요."
                    : "점메추 요정이 이 매장의 대표메뉴로 소개해요"
                }
                onClick={() =>
                  setSignatureIdxs((cur) =>
                    cur.includes(i)
                      ? cur.filter((x) => x !== i)
                      : [...cur, i].slice(0, MAX_SIGNATURE),
                  )
                }
              >
                {signatureIdxs.includes(i) ? "★ 대표" : "☆ 대표로"}
              </button>
            </div>
          ))}
          <button
            type="button"
            className="btn ghost sm"
            onClick={() => setMenu((prev) => [...prev, { name: "", price: 0 }])}
          >
            + 메뉴 추가
          </button>
        </div>

        {error && <p className="form-error">{error}</p>}

        <button type="submit" className="btn primary block" disabled={saving}>
          {saving ? "저장 중…" : mode === "add" ? "매장 추가" : "저장"}
        </button>
      </form>
    </Modal>
  );
}
