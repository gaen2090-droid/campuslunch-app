import { useMemo, useState } from "react";
import { fetchRewardSpendReport } from "../lib/adminApi";
import {
  buildMetricsTsvForClipboard,
  downloadMetricsExcel,
  EXPORT_SECTIONS,
  fmtDate,
  type ExportSection,
} from "../lib/excelExport";
import type { AdminRestaurant } from "../types/restaurant";
import type { DashboardMetrics } from "../types/metrics";
import { Modal } from "./Modal";

interface Props {
  metrics: DashboardMetrics;
  restaurants: AdminRestaurant[];
  onClose: () => void;
}

export function ExportModal({ metrics, restaurants, onClose }: Props) {
  const [selected, setSelected] = useState<Set<ExportSection>>(
    () => new Set(EXPORT_SECTIONS),
  );
  const [startDate, setStartDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() - 29);
    return d.toISOString().slice(0, 10);
  });
  const [endDate, setEndDate] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );
  const [busy, setBusy] = useState(false);
  const [hint, setHint] = useState<string | null>(null);

  const allSelected = selected.size === EXPORT_SECTIONS.length;

  const start = useMemo(() => new Date(startDate), [startDate]);
  const end = useMemo(() => new Date(endDate), [endDate]);

  function toggle(label: ExportSection) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(label)) next.delete(label);
      else next.add(label);
      return next;
    });
  }

  async function buildParams() {
    const needReward = selected.has("리워드 지출");
    const rewardSpend = needReward ? await fetchRewardSpendReport() : null;
    return {
      startDate: start,
      endDate: end,
      sections: selected,
      metrics,
      restaurants,
      rewardSpend,
    };
  }

  async function exportExcel() {
    setBusy(true);
    setHint(null);
    try {
      const params = await buildParams();
      await downloadMetricsExcel(
        `campuslunch_${fmtDate(start)}_${fmtDate(end)}.xlsx`,
        params,
      );
      onClose();
    } catch (e) {
      setHint(e instanceof Error ? e.message : "엑셀 내보내기 실패");
    } finally {
      setBusy(false);
    }
  }

  async function copyForPaste() {
    setBusy(true);
    setHint(null);
    try {
      const params = await buildParams();
      const tsv = await buildMetricsTsvForClipboard(params);
      await navigator.clipboard.writeText(tsv);
      setHint("클립보드에 복사됨 · 엑셀/시트에서 Ctrl/Cmd+V");
      window.setTimeout(() => setHint(null), 2500);
    } catch {
      setHint("복사 실패 · 엑셀 다운로드를 이용해 주세요");
      window.setTimeout(() => setHint(null), 2500);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="지표 내보내기" onClose={onClose}>
      <p className="field-label">기간</p>
      <div className="date-row">
        <input
          type="date"
          value={startDate}
          max={endDate}
          onChange={(e) => setStartDate(e.target.value)}
        />
        <span className="date-sep">~</span>
        <input
          type="date"
          value={endDate}
          min={startDate}
          max={new Date().toISOString().slice(0, 10)}
          onChange={(e) => setEndDate(e.target.value)}
        />
      </div>

      <p className="muted xs" style={{ marginBottom: 12 }}>
        선택한 항목이 <strong>엑셀 시트</strong>로 나뉩니다. DAU는 기준일, MAU는
        매월 1일 갱신으로 표기됩니다. 리워드 지출은 유저별 수령 개수·액수와 총합이
        포함됩니다.
      </p>

      <div className="export-actions">
        <button
          type="button"
          className="btn ghost sm"
          disabled={busy}
          onClick={() =>
            setSelected(allSelected ? new Set() : new Set(EXPORT_SECTIONS))
          }
        >
          {allSelected ? "전체 해제" : "전체 선택"}
        </button>
      </div>

      <ul className="check-list">
        {EXPORT_SECTIONS.map((label) => {
          const checked = selected.has(label);
          return (
            <li key={label}>
              <label className="check-row">
                <input
                  type="checkbox"
                  checked={checked}
                  disabled={busy}
                  onChange={() => toggle(label)}
                />
                <span>{label}</span>
              </label>
            </li>
          );
        })}
      </ul>

      <div className="export-actions" style={{ display: "grid", gap: 8 }}>
        <button
          type="button"
          className="btn primary block"
          disabled={selected.size === 0 || busy}
          onClick={() => void exportExcel()}
        >
          {busy ? "만드는 중…" : "엑셀 다운로드 (.xlsx)"}
        </button>
        <button
          type="button"
          className="btn outline block"
          disabled={selected.size === 0 || busy}
          onClick={() => void copyForPaste()}
        >
          표 복사 (붙여넣기용)
        </button>
        {hint && <p className="muted xs">{hint}</p>}
      </div>
    </Modal>
  );
}
