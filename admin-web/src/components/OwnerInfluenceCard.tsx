import { useEffect, useState } from "react";
import {
  fetchOwnerInfluence,
  ownerInfluenceLabel,
  setOwnerInfluence,
} from "../lib/adminApi";

export function OwnerInfluenceCard() {
  const [value, setValue] = useState(80);
  const [draft, setDraft] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchOwnerInfluence()
      .then(setValue)
      .catch((e) => setError(e instanceof Error ? e.message : String(e)));
  }, []);

  const display = draft ?? value;

  async function save(next: number) {
    setSaving(true);
    setError(null);
    try {
      await setOwnerInfluence(next);
      setValue(next);
      setDraft(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="panel">
      <div className="panel-head">
        <div>
          <h2>혼잡도 계산 설정</h2>
          <p className="muted sm">
            사장님 영향력 · 유저 제보는 충분히 모일 때만 반영
          </p>
        </div>
        <strong className="influence-value">{display}</strong>
      </div>
      <p className="influence-mode">{ownerInfluenceLabel(display)}</p>
      <input
        type="range"
        min={0}
        max={100}
        value={display}
        disabled={saving}
        onChange={(e) => setDraft(Number(e.target.value))}
        onMouseUp={() => draft != null && save(draft)}
        onTouchEnd={() => draft != null && save(draft)}
      />
      {error && <p className="form-error">{error}</p>}
    </section>
  );
}
