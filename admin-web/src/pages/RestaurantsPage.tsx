import { useMemo, useState } from "react";
import { errorMessage } from "../lib/errors";
import {
  deleteRestaurant,
  fetchRecentCrowdReports,
  setRestaurantTier,
  totalReports,
} from "../lib/adminApi";
import type { AdminRestaurant, RecentCrowdReport } from "../types/restaurant";
import { RestaurantFormModal } from "../components/RestaurantFormModal";
import { Pagination } from "../components/Pagination";
import { usePagination } from "../hooks/usePagination";

type CrowdFilter = "crowdOnly" | "collectionOnly" | "all";

interface Props {
  restaurants: AdminRestaurant[];
  onReload: () => void;
}

function statusDotColor(status: string): string {
  switch (status) {
    case "여유로움":
      return "var(--color-brand-primary)";
    case "약간혼잡":
      return "var(--color-warning-strong)";
    case "영업안함":
      return "var(--color-text-disabled)";
    default:
      return "var(--color-border-input)";
  }
}

export function RestaurantsPage({ restaurants, onReload }: Props) {
  const [query, setQuery] = useState("");
  const [crowdFilter, setCrowdFilter] = useState<CrowdFilter>("crowdOnly");
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [reportsCache, setReportsCache] = useState<
    Record<string, RecentCrowdReport[]>
  >({});
  const [reportsLoading, setReportsLoading] = useState<Set<string>>(new Set());
  const [formMode, setFormMode] = useState<"add" | "edit" | null>(null);
  const [editTarget, setEditTarget] = useState<AdminRestaurant | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const filtered = useMemo(() => {
    const sorted = [...restaurants].sort((a, b) =>
      a.name.localeCompare(b.name, "ko"),
    );
    const base =
      crowdFilter === "crowdOnly"
        ? sorted.filter((r) => r.crowdEnabled)
        : crowdFilter === "collectionOnly"
          ? sorted.filter((r) => !r.crowdEnabled)
          : sorted;
    const q = query.trim().toLowerCase();
    if (!q) return base;
    return base.filter(
      (r) =>
        r.name.toLowerCase().includes(q) ||
        r.area.includes(q) ||
        r.category.includes(q),
    );
  }, [restaurants, query, crowdFilter]);

  const { page, setPage, totalPages, pageItems } = usePagination(filtered, 20);

  async function toggleReports(id: string) {
    if (expandedId === id) {
      setExpandedId(null);
      return;
    }
    setExpandedId(id);
    if (reportsCache[id]) return;
    setReportsLoading((prev) => new Set(prev).add(id));
    try {
      const reports = await fetchRecentCrowdReports(id);
      setReportsCache((prev) => ({ ...prev, [id]: reports }));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setReportsLoading((prev) => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
    }
  }

  async function handleMoveTier(id: string, next: "report" | "collection") {
    setBusyId(id);
    setError(null);
    setSuccess(null);
    try {
      await setRestaurantTier(id, next);
      setSuccess(
        next === "report"
          ? "제보 대상(O)으로 옮겼어요."
          : "컬렉션 전용(X)으로 옮겼어요.",
      );
      onReload();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusyId(null);
    }
  }

  async function handleDelete(id: string) {
    setBusyId(id);
    setError(null);
    setSuccess(null);
    try {
      await deleteRestaurant(id);
      setConfirmDeleteId(null);
      setSuccess("매장을 삭제했어요.");
      onReload();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="page">
      {error && <div className="alert">{error}</div>}
      {success && <div className="alert success">{success}</div>}

      <input
        className="search-input"
        placeholder="매장명, 지역, 카테고리 검색"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />

      <div className="radio-group">
        <label className="checkbox-row">
          <input
            type="radio"
            name="crowdFilter"
            checked={crowdFilter === "crowdOnly"}
            onChange={() => setCrowdFilter("crowdOnly")}
          />
          <span>제보 대상 O</span>
        </label>
        <label className="checkbox-row">
          <input
            type="radio"
            name="crowdFilter"
            checked={crowdFilter === "collectionOnly"}
            onChange={() => setCrowdFilter("collectionOnly")}
          />
          <span>제보 대상 X (맛집컬렉션 전용)</span>
        </label>
        <label className="checkbox-row">
          <input
            type="radio"
            name="crowdFilter"
            checked={crowdFilter === "all"}
            onChange={() => setCrowdFilter("all")}
          />
          <span>전체 보기</span>
        </label>
      </div>

      <button
        type="button"
        className="dashed-btn"
        onClick={() => {
          setEditTarget(null);
          setFormMode("add");
        }}
      >
        + 매장 추가
      </button>

      {filtered.length === 0 ? (
        <p className="muted center">검색 결과가 없어요</p>
      ) : (
        <ul className="card-list">
          {pageItems.map((r) => {
            const confirming = confirmDeleteId === r.id;
            const expanded = expandedId === r.id;
            const reports = reportsCache[r.id];
            const loadingReports = reportsLoading.has(r.id);

            return (
              <li key={r.id} className="card">
                <div className="card-top">
                  <div>
                    <div className="card-title-row">
                      <h3>{r.name}</h3>
                      {r.ownerId && (
                        <span className="owner-registered-tag">등록 완료</span>
                      )}
                    </div>
                    {!r.isActive && (
                      <p className="inactive-tag">DB 비활성 (삭제 대상)</p>
                    )}
                    {!r.crowdEnabled && (
                      <p className="inactive-tag">맛집컬렉션 전용 (제보 미지원)</p>
                    )}
                    <p className="muted sm">
                      {r.area} · {r.category}
                    </p>
                    <p
                      className={`status-line${r.hasCrowdUpdate ? "" : " muted"}`}
                    >
                      <span
                        className="status-dot"
                        style={{ background: statusDotColor(r.status) }}
                        aria-hidden="true"
                      />
                      {r.status}
                      {r.hasCrowdUpdate ? ` · ${r.updated}분 전` : ""}
                      {r.crowdBaseSource
                        ? ` (${r.crowdBaseSource}·${r.crowdConfidence})`
                        : ""}
                    </p>
                    <div className="reports-toggle-row">
                      <button
                        type="button"
                        className="link-btn"
                        onClick={() => toggleReports(r.id)}
                      >
                        {expanded ? "▲" : "▼"} 최근 제보
                      </button>
                      <span className="muted xs">
                        누적 제보 {totalReports(r)}건
                      </span>
                    </div>
                    {expanded && (
                      <div className="reports-box">
                        {loadingReports ? (
                          <p className="muted sm">불러오는 중…</p>
                        ) : !reports?.length ? (
                          <p className="muted sm">제보 없음</p>
                        ) : (
                          <ul className="reports-list">
                            {reports.map((rep) => (
                              <li key={rep.id}>
                                {rep.status} · {rep.source} ·{" "}
                                {rep.createdAt.toLocaleString("ko-KR")}
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    )}
                    <div className="owner-code-row">
                      <span className="muted xs">App Link </span>
                      {r.linkNo > 0 ? (
                        <code className="owner-code">
                          https://campuslunch.shop/r/{r.linkNo}
                        </code>
                      ) : (
                        <span className="muted xs">발급 대기중</span>
                      )}
                    </div>
                  </div>
                  <div className="card-actions">
                    {r.crowdEnabled ? (
                      <button
                        type="button"
                        className="btn ghost sm"
                        disabled={busyId === r.id}
                        onClick={() => handleMoveTier(r.id, "collection")}
                      >
                        컬렉션 전용(X)으로
                      </button>
                    ) : (
                      <button
                        type="button"
                        className="btn ghost sm"
                        disabled={busyId === r.id}
                        onClick={() => handleMoveTier(r.id, "report")}
                      >
                        제보 대상(O)으로
                      </button>
                    )}
                    <button
                      type="button"
                      className="icon-btn"
                      aria-label="수정"
                      onClick={() => {
                        setEditTarget(r);
                        setFormMode("edit");
                      }}
                    >
                      ✎
                    </button>
                    <button
                      type="button"
                      className="icon-btn danger"
                      aria-label="삭제"
                      onClick={() =>
                        setConfirmDeleteId(confirming ? null : r.id)
                      }
                    >
                      🗑
                    </button>
                  </div>
                </div>

                {confirming && (
                  <div className="confirm-row">
                    <p>이 매장을 삭제할까요?</p>
                    <button
                      type="button"
                      className="btn ghost sm"
                      onClick={() => setConfirmDeleteId(null)}
                    >
                      취소
                    </button>
                    <button
                      type="button"
                      className="btn danger sm"
                      disabled={busyId === r.id}
                      onClick={() => handleDelete(r.id)}
                    >
                      삭제
                    </button>
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}
      <Pagination page={page} totalPages={totalPages} onChange={setPage} />

      {formMode && (
        <RestaurantFormModal
          mode={formMode}
          restaurant={editTarget ?? undefined}
          defaultCrowdEnabled={crowdFilter !== "collectionOnly"}
          onClose={() => setFormMode(null)}
          onSaved={onReload}
        />
      )}
    </div>
  );
}
