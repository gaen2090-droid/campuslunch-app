import { useState } from "react";
import {
  downloadTrustSignalsExcel,
  TRUST_EXPORT_SHEETS,
  type TrustExportSheet,
} from "../lib/excelExport";
import { errorMessage } from "../lib/errors";
import type { TrustSignalsReport } from "../types/trustAbuse";
import { TrustFieldGlossary } from "./TrustFieldGlossary";
import { Modal } from "./Modal";

interface Props {
  report: TrustSignalsReport;
  days: number;
  onClose: () => void;
}

export function TrustExportModal({ report, days, onClose }: Props) {
  const [selected, setSelected] = useState<Set<TrustExportSheet>>(
    () => new Set(TRUST_EXPORT_SHEETS),
  );
  const [busy, setBusy] = useState(false);
  const [hint, setHint] = useState<string | null>(null);

  const allSelected = selected.size === TRUST_EXPORT_SHEETS.length;

  function toggle(label: TrustExportSheet) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(label)) next.delete(label);
      else next.add(label);
      return next;
    });
  }

  async function exportExcel() {
    setBusy(true);
    setHint(null);
    try {
      await downloadTrustSignalsExcel(
        `campuslunch_trust_signals_${days}d.xlsx`,
        { days, sheets: selected, report },
      );
      onClose();
    } catch (e) {
      setHint(errorMessage(e) || "내보내기 실패");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="신뢰·어뷰징 수집 지표 내보내기" onClose={onClose}>
      <p className="muted xs mb-3">
        핵심 지표와 <strong>별도 카테고리</strong>입니다. 점수·판정 없이 원본
        수치만 포함합니다. 최근 {days}일 · {report.users.length}명.
      </p>

      <div style={{ marginBottom: 12 }}>
        <TrustFieldGlossary />
      </div>

      <div className="export-actions">
        <button
          type="button"
          className="btn ghost sm"
          disabled={busy}
          onClick={() =>
            setSelected(
              allSelected ? new Set() : new Set(TRUST_EXPORT_SHEETS),
            )
          }
        >
          {allSelected ? "전체 해제" : "전체 선택"}
        </button>
      </div>

      <ul className="check-list">
        {TRUST_EXPORT_SHEETS.map((label) => (
          <li key={label}>
            <label className="check-row">
              <input
                type="checkbox"
                checked={selected.has(label)}
                disabled={busy}
                onChange={() => toggle(label)}
              />
              <span>{label}</span>
            </label>
          </li>
        ))}
      </ul>

      <div className="export-actions">
        <button
          type="button"
          className="btn primary block"
          disabled={selected.size === 0 || busy || report.users.length === 0}
          onClick={() => void exportExcel()}
        >
          {busy ? "만드는 중…" : "엑셀 다운로드 (.xlsx)"}
        </button>
        {hint && <p className="muted xs">{hint}</p>}
      </div>
    </Modal>
  );
}
