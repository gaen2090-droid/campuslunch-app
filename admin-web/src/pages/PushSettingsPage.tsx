import { useEffect, useState } from "react";
import {
  fetchPushOpsSnapshot,
  invokePushEdge,
  updatePushNotificationConfig,
} from "../lib/adminApi";
import {
  DEFAULT_PUSH_CONFIG,
  EMPTY_PUSH_OPS,
  formatTime,
  newPeakSchedule,
  previewCommunityTemplate,
  type PeakPushSchedule,
  type PushNotificationConfig,
  type PushOpsSnapshot,
} from "../types/pushConfig";

interface Props {
  config: PushNotificationConfig | null;
  loading: boolean;
  error: string | null;
  onReload: () => void;
}

export function PushSettingsPage({ config, loading, error, onReload }: Props) {
  const [form, setForm] = useState<PushNotificationConfig>(DEFAULT_PUSH_CONFIG);
  const [ops, setOps] = useState<PushOpsSnapshot>(EMPTY_PUSH_OPS);
  const [opsLoading, setOpsLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [actionBusy, setActionBusy] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    if (config) setForm(config);
  }, [config]);

  async function reloadOps() {
    setOpsLoading(true);
    try {
      setOps(await fetchPushOpsSnapshot());
    } catch (err) {
      console.error(err);
    } finally {
      setOpsLoading(false);
    }
  }

  useEffect(() => {
    void reloadOps();
  }, []);

  function patch(partial: Partial<PushNotificationConfig>) {
    setForm((prev) => ({ ...prev, ...partial }));
  }

  function patchSchedule(index: number, partial: Partial<PeakPushSchedule>) {
    setForm((prev) => {
      const schedules = prev.schedules.map((s, i) =>
        i === index ? { ...s, ...partial } : s,
      );
      return { ...prev, schedules };
    });
  }

  function addSchedule() {
    setForm((prev) => {
      if (prev.schedules.length >= 8) return prev;
      return {
        ...prev,
        schedules: [...prev.schedules, newPeakSchedule(prev.schedules.length)],
      };
    });
  }

  function removeSchedule(index: number) {
    setForm((prev) => {
      if (prev.schedules.length <= 1) return prev;
      return {
        ...prev,
        schedules: prev.schedules.filter((_, i) => i !== index),
      };
    });
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormError(null);
    setSuccess(null);
    try {
      const saved = await updatePushNotificationConfig(form);
      setForm(saved);
      setSuccess("저장했어요. 앱은 다음 실행·설정 전파 시 반영됩니다.");
      onReload();
      await reloadOps();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  async function runAction(action: string, label: string) {
    setActionBusy(action);
    setFormError(null);
    setSuccess(null);
    try {
      const result = await invokePushEdge(action);
      setSuccess(`${label} 완료: ${JSON.stringify(result)}`);
      await reloadOps();
    } catch (err) {
      setFormError(
        err instanceof Error
          ? `${label} 실패: ${err.message}`
          : `${label} 실패: ${String(err)}`,
      );
    } finally {
      setActionBusy(null);
    }
  }

  const enabledSchedules = form.schedules.filter((s) => s.enabled);

  return (
    <div className="page push-page">
      <div className="panel-head push-page-head">
        <div>
          <h2>푸시 알림 설정</h2>
          <p className="muted sm">
            피크 스케줄·문구 자유 편집 · 커뮤니티 댓글{" "}
            <code>{"{nickname}"}</code> <code>{"{content}"}</code>
          </p>
        </div>
      </div>

      {error && <div className="alert">{error}</div>}
      {formError && <div className="alert">{formError}</div>}
      {success && <div className="alert success">{success}</div>}

      <div className="panel push-ops compact">
        <div className="push-ops-top">
          <div className="push-ops-stats">
            <span>
              토큰 <strong>{ops.tokenCount}</strong>
              <em>({ops.uniqueUsersWithToken}명)</em>
            </span>
            <span>
              점심 <strong>{ops.peakLunchOn}</strong>
            </span>
            <span>
              저녁 <strong>{ops.peakDinnerOn}</strong>
            </span>
            <span>
              커뮤니티 <strong>{ops.communityOn}</strong>
            </span>
          </div>
          <button
            type="button"
            className="btn ghost sm"
            disabled={opsLoading}
            onClick={() => void reloadOps()}
          >
            {opsLoading ? "…" : "새로고침"}
          </button>
        </div>
        <div className="push-ops-actions">
          {enabledSchedules.slice(0, 4).map((s) => (
            <button
              key={s.id}
              type="button"
              className="btn sm"
              disabled={actionBusy != null || !form.peakFcmEnabled}
              onClick={() => void runAction(s.id, `${s.label} 테스트`)}
            >
              {actionBusy === s.id ? "…" : `${s.label} 테스트`}
            </button>
          ))}
          <button
            type="button"
            className="btn primary sm"
            disabled={actionBusy != null}
            onClick={() => void runAction("config_refresh", "설정 전파")}
          >
            {actionBusy === "config_refresh" ? "…" : "설정 전파"}
          </button>
        </div>
        {ops.lastPeakSent.length > 0 && (
          <p className="push-ops-log-inline muted sm">
            최근:{" "}
            {ops.lastPeakSent
              .slice(0, 3)
              .map(
                (row) =>
                  `${row.sentDate} ${row.slot}${
                    row.createdAt
                      ? ` ${new Date(row.createdAt).toLocaleTimeString("ko-KR", {
                          hour: "2-digit",
                          minute: "2-digit",
                        })}`
                      : ""
                  }`,
              )
              .join(" · ")}
          </p>
        )}
      </div>

      {loading && !config ? (
        <p className="muted center">불러오는 중…</p>
      ) : (
        <form className="panel push-form" onSubmit={(e) => void submit(e)}>
          <section className="push-section">
            <div className="push-section-head row">
              <h3>피크 추천</h3>
              <label className="field inline-days">
                <span>예약 일수</span>
                <input
                  type="number"
                  min={1}
                  max={30}
                  value={form.scheduleDaysAhead}
                  onChange={(e) =>
                    patch({
                      scheduleDaysAhead:
                        Number.parseInt(e.target.value, 10) ||
                        DEFAULT_PUSH_CONFIG.scheduleDaysAhead,
                    })
                  }
                />
              </label>
            </div>

            <div className="toggle-row-inline">
              <label className="chip-toggle">
                <input
                  type="checkbox"
                  checked={form.peakLocalScheduleEnabled}
                  onChange={(e) =>
                    patch({ peakLocalScheduleEnabled: e.target.checked })
                  }
                />
                로컬 예약
              </label>
              <label className="chip-toggle">
                <input
                  type="checkbox"
                  checked={form.peakFcmEnabled}
                  onChange={(e) => patch({ peakFcmEnabled: e.target.checked })}
                />
                서버 FCM
              </label>
              <label className="chip-toggle">
                <input
                  type="checkbox"
                  checked={form.weekdaysOnly}
                  onChange={(e) => patch({ weekdaysOnly: e.target.checked })}
                />
                평일만
              </label>
            </div>

            <div className="peak-schedule-list">
              {form.schedules.map((s, index) => (
                <div
                  key={s.id}
                  className={`peak-schedule-card${s.enabled ? "" : " off"}`}
                >
                  <div className="peak-schedule-toolbar">
                    <label className="chip-toggle">
                      <input
                        type="checkbox"
                        checked={s.enabled}
                        onChange={(e) =>
                          patchSchedule(index, { enabled: e.target.checked })
                        }
                      />
                      ON
                    </label>
                    <input
                      className="peak-schedule-label"
                      type="text"
                      value={s.label}
                      onChange={(e) =>
                        patchSchedule(index, { label: e.target.value })
                      }
                      placeholder="이름"
                    />
                    <div className="time-row compact">
                      <input
                        type="number"
                        min={0}
                        max={23}
                        value={s.hour}
                        onChange={(e) =>
                          patchSchedule(index, {
                            hour: Number.parseInt(e.target.value, 10) || 0,
                          })
                        }
                        aria-label="시"
                      />
                      <span>:</span>
                      <input
                        type="number"
                        min={0}
                        max={59}
                        value={s.minute}
                        onChange={(e) =>
                          patchSchedule(index, {
                            minute: Number.parseInt(e.target.value, 10) || 0,
                          })
                        }
                        aria-label="분"
                      />
                    </div>
                    <span className="muted sm peak-time-hint">
                      {formatTime(s.hour, s.minute)}
                    </span>
                    <button
                      type="button"
                      className="btn ghost sm"
                      disabled={form.schedules.length <= 1}
                      onClick={() => removeSchedule(index)}
                    >
                      삭제
                    </button>
                  </div>
                  <input
                    className="peak-title"
                    type="text"
                    value={s.titleTemplate}
                    onChange={(e) =>
                      patchSchedule(index, { titleTemplate: e.target.value })
                    }
                    placeholder="제목"
                  />
                  <textarea
                    className="peak-body"
                    rows={2}
                    value={s.bodyTemplate}
                    onChange={(e) =>
                      patchSchedule(index, { bodyTemplate: e.target.value })
                    }
                    placeholder="본문"
                  />
                </div>
              ))}
            </div>

            <button
              type="button"
              className="btn sm"
              disabled={form.schedules.length >= 8}
              onClick={addSchedule}
            >
              + 스케줄 추가
            </button>
          </section>

          <section className="push-section">
            <div className="push-section-head row">
              <h3>커뮤니티</h3>
              <label className="chip-toggle">
                <input
                  type="checkbox"
                  checked={form.communityFcmEnabled}
                  onChange={(e) =>
                    patch({ communityFcmEnabled: e.target.checked })
                  }
                />
                FCM
              </label>
            </div>

            <div className="community-fields">
              <label className="field">
                <span className="field-label">댓글 제목</span>
                <input
                  type="text"
                  value={form.communityCommentTitleTemplate}
                  onChange={(e) =>
                    patch({ communityCommentTitleTemplate: e.target.value })
                  }
                />
                <span className="field-hint">
                  {previewCommunityTemplate(form.communityCommentTitleTemplate)}
                </span>
              </label>
              <label className="field">
                <span className="field-label">댓글 본문</span>
                <input
                  type="text"
                  value={form.communityCommentBodyTemplate}
                  onChange={(e) =>
                    patch({ communityCommentBodyTemplate: e.target.value })
                  }
                />
                <span className="field-hint">
                  {previewCommunityTemplate(form.communityCommentBodyTemplate)}
                </span>
              </label>
            </div>
          </section>

          <div className="form-actions sticky-save">
            <button type="submit" className="btn primary" disabled={saving}>
              {saving ? "저장 중…" : "설정 저장"}
            </button>
            {form.updatedAt && (
              <span className="muted sm">
                {form.updatedAt.toLocaleString("ko-KR")}
              </span>
            )}
          </div>
        </form>
      )}
    </div>
  );
}
