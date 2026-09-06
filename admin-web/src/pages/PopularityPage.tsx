import { useMemo, useState } from "react";
import { errorMessage } from "../lib/errors";
import {
  totalReports,
  updateManualRanks,
} from "../lib/adminApi";
import { getUseAlgorithmRanking, setUseAlgorithmRanking } from "../lib/settings";
import type { AdminRestaurant } from "../types/restaurant";

interface Props {
  restaurants: AdminRestaurant[];
  onReload: () => void;
}

function sortRestaurants(
  list: AdminRestaurant[],
  useAlgo: boolean,
): AdminRestaurant[] {
  const copy = [...list];
  if (useAlgo) {
    copy.sort((a, b) => {
      const aScore = a.popularityScore > 0 ? a.popularityScore : totalReports(a);
      const bScore = b.popularityScore > 0 ? b.popularityScore : totalReports(b);
      const diff = bScore - aScore;
      return diff !== 0 ? diff : a.name.localeCompare(b.name, "ko");
    });
  } else {
    copy.sort((a, b) => {
      if (a.manualRank === 0 && b.manualRank === 0) {
        return a.name.localeCompare(b.name, "ko");
      }
      if (a.manualRank === 0) return 1;
      if (b.manualRank === 0) return -1;
      return a.manualRank - b.manualRank;
    });
  }
  return copy;
}

export function PopularityPage({ restaurants, onReload }: Props) {
  const [useAlgo, setUseAlgo] = useState(getUseAlgorithmRanking);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [manualOrder, setManualOrder] = useState<string[] | null>(null);

  // 맛집컬렉션 전용(제보 미지원) 매장은 혼잡도 기반 인기 순위 대상이 아니다.
  const rankable = useMemo(
    () => restaurants.filter((r) => r.crowdEnabled),
    [restaurants],
  );

  const sorted = useMemo(() => {
    const base = sortRestaurants(rankable, useAlgo);
    if (!useAlgo && manualOrder) {
      const map = new Map(base.map((r) => [r.id, r]));
      return manualOrder
        .map((id) => map.get(id))
        .filter((r): r is AdminRestaurant => r != null);
    }
    return base;
  }, [rankable, useAlgo, manualOrder]);

  async function toggleAlgo() {
    const next = !useAlgo;
    setUseAlgo(next);
    setUseAlgorithmRanking(next);
    setManualOrder(null);

    if (!next) {
      const allUnranked = rankable.every((r) => r.manualRank === 0);
      if (allUnranked) {
        const algoSorted = sortRestaurants(rankable, true);
        await persistOrder(algoSorted.map((r) => r.id));
      }
    }
  }

  async function persistOrder(ids: string[]) {
    setSaving(true);
    setError(null);
    try {
      const rankById: Record<string, number> = {};
      ids.forEach((id, i) => {
        rankById[id] = i + 1;
      });
      await updateManualRanks(rankById);
      setManualOrder(ids);
      onReload();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setSaving(false);
    }
  }

  function moveItem(index: number, direction: -1 | 1) {
    const ids = sorted.map((r) => r.id);
    const target = index + direction;
    if (target < 0 || target >= ids.length) return;
    [ids[index], ids[target]] = [ids[target], ids[index]];
    setManualOrder(ids);
    void persistOrder(ids);
  }

  return (
    <div className="page">
      {error && <div className="alert">{error}</div>}

      <section className="panel toggle-panel">
        <div className="panel-head">
          <div>
            <h2>인기도 알고리즘</h2>
            <p className="muted sm">최근 1주 혼잡도 지속시간 기반 자동 측정</p>
          </div>
          <button
            type="button"
            className={`toggle${useAlgo ? " on" : ""}`}
            onClick={toggleAlgo}
            aria-pressed={useAlgo}
          >
            <span className="toggle-knob" />
          </button>
        </div>
      </section>

      <div className="section-head">
        <h2>매장별 순위</h2>
        <p className="muted sm">
          {useAlgo
            ? "알고리즘이 자동으로 산정한 순위예요"
            : "↑↓ 버튼으로 순서를 바꿔보세요"}
        </p>
      </div>

      <ul className="rank-cards">
        {sorted.map((r, i) => (
          <li key={r.id} className="rank-card">
            <span className="rank-badge">{i + 1}</span>
            <div className="rank-info">
              <strong>{r.name}</strong>
              <span className="muted sm">
                {r.area} · {r.category}
              </span>
            </div>
            {!useAlgo && (
              <div className="rank-move">
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={saving || i === 0}
                  onClick={() => moveItem(i, -1)}
                >
                  ↑
                </button>
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={saving || i === sorted.length - 1}
                  onClick={() => moveItem(i, 1)}
                >
                  ↓
                </button>
              </div>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
