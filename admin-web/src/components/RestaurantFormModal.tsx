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
  const [signatureIdx, setSignatureIdx] = useState<number | null>(() => {
    const sig = restaurant?.signatureMenu?.trim();
    if (!sig || !restaurant) return null;
    const idx = restaurant.menu.findIndex((m) => m.name.trim() === sig);
    return idx >= 0 ? idx : null;
  });
  const [soloFriendly, setSoloFriendly] = useState(
    restaurant?.soloFriendly ?? false,
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

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) {
      setError("매장명을 입력해주세요.");
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
      const validMenu = menu.filter((m) => m.name.trim());
      const signatureName =
        signatureIdx != null ? (menu[signatureIdx]?.name.trim() ?? "") : "";
      const data: RestaurantFormData = {
        name: name.trim(),
        area,
        category,
        address: area,
        hours,
        menu: validMenu,
        crowd_enabled: crowdEnabled,
        solo_friendly: soloFriendly,
        signature_menu: signatureName,
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
          <span className="field-label">매장명 *</span>
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </label>

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
              (점심메뉴 요정에서 &quot;혼밥&quot; 선택 시 우선 추천돼요)
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
          <span className="field-label">메뉴</span>
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
              <button
                type="button"
                className={`btn sm ${signatureIdx === i ? "primary" : "ghost"}`}
                disabled={!item.name.trim()}
                title="점심메뉴 요정이 이 매장의 대표메뉴로 소개해요"
                onClick={() =>
                  setSignatureIdx((cur) => (cur === i ? null : i))
                }
              >
                {signatureIdx === i ? "★ 대표" : "☆ 대표로"}
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
