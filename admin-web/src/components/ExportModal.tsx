import { useMemo, useState } from "react";
import {
  fetchAdminUsers,
  fetchRewardSpendReport,
  type RewardSpendReport,
} from "../lib/adminApi";
import {
  fetchRealtimeMetrics,
  fetchKpiMetrics,
  fetchOpsMetrics,
  fetchDailyExportMetrics,
  fetchHourlyExportMetrics,
  fetchRestaurantExportMetrics,
} from "../lib/metrics";
import {
  buildMetricsTsvForClipboard,
  downloadMetricsExcel,
  EXPORT_SECTIONS,
  fmtDate,
  type ExportSection,
} from "../lib/excelExport";
import { errorMessage } from "../lib/errors";
import type { AdminRestaurant } from "../types/restaurant";
import { Modal } from "./Modal";

interface Props {
  restaurants: AdminRestaurant[];
  onClose: () => void;
}

export function ExportModal({ restaurants, onClose }: Props) {
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

  async function loadRewardSpend(): Promise<{
    report: RewardSpendReport | null;
    warning: string | null;
  }> {
    if (!selected.has("리워드 지출")) {
      return { report: null, warning: null };
    }
    try {
      return { report: await fetchRewardSpendReport(), warning: null };
    } catch (e) {
      // 리워드 집계 실패해도 나머지 섹션은 내보낼 수 있어야 함
      console.error("[ExportModal] fetchRewardSpendReport failed:", e);
      return {
        report: {
          totalRewardCount: 0,
          totalAmountKrw: 0,
          attributedCount: 0,
          unattributedCount: 0,
          missingFaceValueCount: 0,
          users: [],
        },
        warning: `리워드 지출 조회 실패 · 나머지 시트만 포함 (${errorMessage(e)})`,
      };
    }
  }

  async function buildParams() {
    const { report: rewardSpend, warning: rewardWarning } =
      await loadRewardSpend();
    const warnings: string[] = [];
    if (rewardWarning) warnings.push(rewardWarning);

    const rangeStart = fmtDate(Number.isFinite(start.getTime()) ? start : new Date());
    const rangeEnd = fmtDate(Number.isFinite(end.getTime()) ? end : new Date());

    const [realtimeMetrics, kpiMetrics, opsMetrics, users, dailyRows, hourlyRows, restaurantRows] =
      await Promise.all([
        fetchRealtimeMetrics().catch((e) => {
          warnings.push(`실시간 지표 조회 실패 (${errorMessage(e)})`);
          return null;
        }),
        fetchKpiMetrics().catch((e) => {
          warnings.push(`KPI 지표 조회 실패 (${errorMessage(e)})`);
          return null;
        }),
        fetchOpsMetrics().catch((e) => {
          warnings.push(`운영 성과 지표 조회 실패 (${errorMessage(e)})`);
          return null;
        }),
        fetchAdminUsers().catch((e) => {
          warnings.push(`회원 목록 조회 실패 (${errorMessage(e)})`);
          return [];
        }),
        fetchDailyExportMetrics(rangeStart, rangeEnd).catch((e) => {
          warnings.push(`일별 지표 조회 실패 (${errorMessage(e)})`);
          return [];
        }),
        fetchHourlyExportMetrics(rangeStart, rangeEnd).catch((e) => {
          warnings.push(`시간대별 지표 조회 실패 (${errorMessage(e)})`);
          return [];
        }),
        fetchRestaurantExportMetrics(rangeStart, rangeEnd).catch((e) => {
          warnings.push(`매장별 지표 조회 실패 (${errorMessage(e)})`);
          return [];
        }),
      ]);

    return {
      startDate: Number.isFinite(start.getTime()) ? start : new Date(),
      endDate: Number.isFinite(end.getTime()) ? end : new Date(),
      sections: selected,
      realtimeMetrics,
      kpiMetrics,
      opsMetrics,
      dailyRows,
      hourlyRows,
      restaurantRows,
      restaurants,
      users,
      rewardSpend,
      warning: warnings.length > 0 ? warnings.join(" · ") : null,
    };
  }

  async function exportExcel() {
    setBusy(true);
    setHint(null);
    try {
      const params = await buildParams();
      const { warning, ...exportParams } = params;
      await downloadMetricsExcel(
        `campuslunch_${fmtDate(exportParams.startDate)}_${fmtDate(exportParams.endDate)}.xlsx`,
        exportParams,
      );
      if (warning) {
        setHint(warning);
        window.setTimeout(() => setHint(null), 4000);
        return;
      }
      onClose();
    } catch (e) {
      setHint(errorMessage(e) || "엑셀 내보내기 실패");
    } finally {
      setBusy(false);
    }
  }

  async function copyForPaste() {
    setBusy(true);
    setHint(null);
    try {
      const params = await buildParams();
      const { warning, ...exportParams } = params;
      const tsv = await buildMetricsTsvForClipboard(exportParams);
      await navigator.clipboard.writeText(tsv);
      setHint(
        warning
          ? `${warning} · 표는 클립보드에 복사됨`
          : "클립보드에 복사됨 · 엑셀/시트에서 Ctrl/Cmd+V",
      );
      window.setTimeout(() => setHint(null), 3500);
    } catch (e) {
      setHint(`복사 실패 · ${errorMessage(e)}`);
      window.setTimeout(() => setHint(null), 3500);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="핵심 지표 내보내기" onClose={onClose}>
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

      <p className="muted xs mb-3">
        실시간 지표·KPI·운영 성과·리워드 등 <strong>핵심 지표</strong>용입니다.
        신뢰·어뷰징 원본 수치는 <strong>신뢰·어뷰징</strong> 탭에서 따로
        내보내세요.
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

      <div className="export-actions">
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
