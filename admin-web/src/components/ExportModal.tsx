import { useMemo, useState } from "react";
import {
  buildMetricsCsv,
  downloadCsv,
  EXPORT_SECTIONS,
  fmtDate,
  type ExportSection,
} from "../lib/csvExport";
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

  function exportCsv() {
    const csv = buildMetricsCsv({
      startDate: start,
      endDate: end,
      sections: selected,
      metrics,
      restaurants,
    });
    downloadCsv(
      `campuslunch_${fmtDate(start)}_${fmtDate(end)}.csv`,
      csv,
    );
    onClose();
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

      <div className="export-actions">
        <button
          type="button"
          className="btn ghost sm"
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
                  onChange={() => toggle(label)}
                />
                <span>{label}</span>
              </label>
            </li>
          );
        })}
      </ul>

      <button
        type="button"
        className="btn primary block"
        disabled={selected.size === 0}
        onClick={exportCsv}
      >
        CSV로 내보내기 (.csv)
      </button>
    </Modal>
  );
}
