import { useState } from "react";
import { Modal } from "./Modal";
import { errorMessage } from "../lib/errors";
import {
  KPI_METRIC_LABELS,
  type KpiMetricKey,
  type KpiTarget,
  monthKeyOf,
} from "../types/kpiTarget";

interface Props {
  targets: KpiTarget[];
  onSave: (metricKey: KpiMetricKey, periodMonth: Date, targetValue: number) => Promise<void>;
  onClose: () => void;
}

const METRIC_KEYS: KpiMetricKey[] = [
  "new_users",
  "lunch_dau",
  "wau",
  "reports",
  "report_participants",
  "coverage",
];

export function KpiGoalModal({ targets, onSave, onClose }: Props) {
  const now = new Date();
  const thisMonthKey = monthKeyOf(now);
  const existing = new Map(
    targets
      .filter((t) => monthKeyOf(t.periodMonth) === thisMonthKey)
      .map((t) => [t.metricKey, t.targetValue]),
  );

  const [values, setValues] = useState<Record<KpiMetricKey, string>>(() => {
    const initial = {} as Record<KpiMetricKey, string>;
    for (const key of METRIC_KEYS) {
      initial[key] = String(existing.get(key) ?? "");
    }
    return initial;
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSave() {
    setSaving(true);
    setError(null);
    try {
      for (const key of METRIC_KEYS) {
        const raw = values[key].trim();
        const num = raw === "" ? 0 : Number.parseInt(raw, 10);
        if (Number.isNaN(num) || num < 0) continue;
        await onSave(key, now, num);
      }
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal title="이번 달 KPI 목표 설정" onClose={onClose}>
      {error && <div className="alert">{error}</div>}
      <div className="form-grid">
        {METRIC_KEYS.map((key) => (
          <label key={key} className="field">
            <span>{KPI_METRIC_LABELS[key]}</span>
            <input
              type="number"
              min={0}
              max={key === "coverage" ? 100 : undefined}
              inputMode="numeric"
              value={values[key]}
              onChange={(e) =>
                setValues((prev) => ({ ...prev, [key]: e.target.value }))
              }
              placeholder="목표 숫자 입력"
            />
          </label>
        ))}
      </div>
      <div className="row-actions mt-8">
        <button type="button" className="btn ghost" onClick={onClose} disabled={saving}>
          취소
        </button>
        <button type="button" className="btn" onClick={() => void handleSave()} disabled={saving}>
          {saving ? "저장 중…" : "저장"}
        </button>
      </div>
    </Modal>
  );
}
