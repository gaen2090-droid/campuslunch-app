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
  previewCommunityTemplate,
  previewTitle,
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

  async function runAction(
    action: "peak_lunch" | "peak_dinner" | "config_refresh",
    label: string,
  ) {
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

  return (
    <div className="page">
      <div className="panel-head">
        <div>
          <h2>푸시 알림 설정</h2>
          <p className="muted sm">
            피크는 로컬 예약이 기본 · 커뮤니티는 인박스와 같은 이벤트를 FCM으로
            보냅니다.
          </p>
        </div>
      </div>

      <div className="info-panel warn">
        <strong>플레이스홀더</strong>
        <ul>
          <li>
            피크: <code>{"{gate}"}</code> (필수)
          </li>
          <li>
            커뮤니티: <code>{"{nickname}"}</code>{" "}
            <code>{"{content}"}</code> <code>{"{post_preview}"}</code>
          </li>
        </ul>
      </div>

      {error && <div className="alert">{error}</div>}
      {formError && <div className="alert">{formError}</div>}
      {success && <div className="alert success">{success}</div>}

      <div className="panel push-ops">
        <div className="panel-head">
          <h3>운영 현황</h3>
          <button
            type="button"
            className="btn ghost"
            disabled={opsLoading}
            onClick={() => void reloadOps()}
          >
            {opsLoading ? "갱신 중…" : "새로고침"}
          </button>
        </div>
        <div className="push-ops-grid">
          <div className="push-ops-card">
            <span className="muted sm">FCM 토큰</span>
            <strong>{ops.tokenCount}</strong>
            <span className="muted sm">유저 {ops.uniqueUsersWithToken}명</span>
          </div>
          <div className="push-ops-card">
            <span className="muted sm">점심 ON</span>
            <strong>{ops.peakLunchOn}</strong>
          </div>
          <div className="push-ops-card">
            <span className="muted sm">저녁 ON</span>
            <strong>{ops.peakDinnerOn}</strong>
          </div>
          <div className="push-ops-card">
            <span className="muted sm">커뮤니티 ON</span>
            <strong>{ops.communityOn}</strong>
          </div>
        </div>
        {ops.lastPeakSent.length > 0 && (
          <div className="push-ops-log">
            <p className="muted sm">최근 피크 FCM 발송 로그</p>
            <ul>
              {ops.lastPeakSent.map((row) => (
                <li key={`${row.sentDate}-${row.slot}-${row.createdAt}`}>
                  {row.sentDate} · {row.slot} ·{" "}
                  {row.createdAt
                    ? new Date(row.createdAt).toLocaleString("ko-KR")
                    : "-"}
                </li>
              ))}
            </ul>
          </div>
        )}
        <div className="push-ops-actions">
          <button
            type="button"
            className="btn"
            disabled={actionBusy != null || !form.peakFcmEnabled}
            onClick={() => void runAction("peak_lunch", "점심 테스트 발송")}
          >
            {actionBusy === "peak_lunch" ? "발송 중…" : "점심 테스트 FCM"}
          </button>
          <button
            type="button"
            className="btn"
            disabled={actionBusy != null || !form.peakFcmEnabled}
            onClick={() => void runAction("peak_dinner", "저녁 테스트 발송")}
          >
            {actionBusy === "peak_dinner" ? "발송 중…" : "저녁 테스트 FCM"}
          </button>
          <button
            type="button"
            className="btn primary"
            disabled={actionBusy != null}
            onClick={() => void runAction("config_refresh", "설정 전파")}
          >
            {actionBusy === "config_refresh"
              ? "전파 중…"
              : "설정 전파 (로컬 재예약)"}
          </button>
        </div>
      </div>

      {loading && !config ? (
        <p className="muted center">불러오는 중…</p>
      ) : (
        <form
          className="panel push-form"
          onSubmit={(e) => void submit(e)}
        >
          <section className="push-section">
            <div className="push-section-head">
              <h3>1. 피크 추천 알림</h3>
              <p className="muted sm">
                로컬 예약이 기본입니다. 시각·문구는 서버에서 앱으로 내려갑니다.
              </p>
            </div>

            <div className="toggle-stack">
              <label className="toggle-row">
                <input
                  type="checkbox"
                  checked={form.peakLocalScheduleEnabled}
                  onChange={(e) =>
                    patch({ peakLocalScheduleEnabled: e.target.checked })
                  }
                />
                <span>
                  <strong>로컬 예약</strong>
                  <span className="toggle-desc">
                    기기 zonedSchedule · 기본 ON
                  </span>
                </span>
              </label>
              <label className="toggle-row">
                <input
                  type="checkbox"
                  checked={form.peakFcmEnabled}
                  onChange={(e) => patch({ peakFcmEnabled: e.target.checked })}
                />
                <span>
                  <strong>서버 FCM</strong>
                  <span className="toggle-desc">
                    앱 종료 시에도 발송 · cron 필요 · 선택
                  </span>
                </span>
              </label>
              <label className="toggle-row">
                <input
                  type="checkbox"
                  checked={form.weekdaysOnly}
                  onChange={(e) => patch({ weekdaysOnly: e.target.checked })}
                />
                <span>
                  <strong>평일만</strong>
                  <span className="toggle-desc">월~금만 발송</span>
                </span>
              </label>
            </div>

            <div className="push-section-grid">
              <label className="field">
                <span className="field-label">점심 (KST)</span>
                <div className="time-row">
                  <input
                    type="number"
                    min={0}
                    max={23}
                    value={form.lunchHour}
                    onChange={(e) =>
                      patch({
                        lunchHour: Number.parseInt(e.target.value, 10) || 0,
                      })
                    }
                  />
                  <span>:</span>
                  <input
                    type="number"
                    min={0}
                    max={59}
                    value={form.lunchMinute}
                    onChange={(e) =>
                      patch({
                        lunchMinute: Number.parseInt(e.target.value, 10) || 0,
                      })
                    }
                  />
                </div>
              </label>

              <label className="field">
                <span className="field-label">저녁 (KST)</span>
                <div className="time-row">
                  <input
                    type="number"
                    min={0}
                    max={23}
                    value={form.dinnerHour}
                    onChange={(e) =>
                      patch({
                        dinnerHour: Number.parseInt(e.target.value, 10) || 0,
                      })
                    }
                  />
                  <span>:</span>
                  <input
                    type="number"
                    min={0}
                    max={59}
                    value={form.dinnerMinute}
                    onChange={(e) =>
                      patch({
                        dinnerMinute: Number.parseInt(e.target.value, 10) || 0,
                      })
                    }
                  />
                </div>
              </label>

              <label className="field">
                <span className="field-label">로컬 미리 예약 일수</span>
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

              <label className="field full">
                <span className="field-label">
                  제목 · <code>{"{gate}"}</code> 필수
                </span>
                <input
                  type="text"
                  value={form.titleTemplate}
                  onChange={(e) => patch({ titleTemplate: e.target.value })}
                  placeholder="{gate}에서 대기 없이 식사할 수 있어요"
                />
              </label>

              <label className="field full">
                <span className="field-label">본문</span>
                <textarea
                  rows={3}
                  value={form.bodyTemplate}
                  onChange={(e) => patch({ bodyTemplate: e.target.value })}
                />
              </label>

              <div className="push-preview inset">
                <p className="muted sm">미리보기</p>
                <strong>{previewTitle(form.titleTemplate)}</strong>
                <p className="push-preview-body">{form.bodyTemplate}</p>
                <p className="muted sm">
                  점심 {formatTime(form.lunchHour, form.lunchMinute)} · 저녁{" "}
                  {formatTime(form.dinnerHour, form.dinnerMinute)}
                  {form.weekdaysOnly ? " · 평일" : " · 매일"}
                  {form.peakLocalScheduleEnabled ? " · 로컬" : " · 로컬꺼짐"}
                  {form.peakFcmEnabled ? " · FCM" : ""}
                </p>
              </div>
            </div>
          </section>

          <section className="push-section">
            <div className="push-section-head">
              <h3>2. 커뮤니티 푸시</h3>
              <p className="muted sm">
                댓글 알림만 앱 푸시로 발송돼요. FCM 문구는 여기서 수정합니다.
              </p>
            </div>

            <div className="toggle-stack">
              <label className="toggle-row">
                <input
                  type="checkbox"
                  checked={form.communityFcmEnabled}
                  onChange={(e) =>
                    patch({ communityFcmEnabled: e.target.checked })
                  }
                />
                <span>
                  <strong>커뮤니티 서버 FCM</strong>
                  <span className="toggle-desc">
                    내 글 댓글 · 알림 켠 글 댓글
                  </span>
                </span>
              </label>
            </div>

            <div className="push-section-grid">
              <label className="field full">
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

              <label className="field full">
                <span className="field-label">댓글 본문</span>
                <textarea
                  rows={2}
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

          <div className="form-actions">
            <button type="submit" className="btn primary" disabled={saving}>
              {saving ? "저장 중…" : "설정 저장"}
            </button>
            {form.updatedAt && (
              <span className="muted sm">
                마지막 저장: {form.updatedAt.toLocaleString("ko-KR")}
              </span>
            )}
          </div>
        </form>
      )}
    </div>
  );
}
