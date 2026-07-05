import { useEffect, useState } from "react";
import { updatePushNotificationConfig } from "../lib/adminApi";
import {
  DEFAULT_PUSH_CONFIG,
  formatTime,
  previewTitle,
  type PushNotificationConfig,
} from "../types/pushConfig";

interface Props {
  config: PushNotificationConfig | null;
  loading: boolean;
  error: string | null;
  onReload: () => void;
}

export function PushSettingsPage({ config, loading, error, onReload }: Props) {
  const [form, setForm] = useState<PushNotificationConfig>(DEFAULT_PUSH_CONFIG);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    if (config) setForm(config);
  }, [config]);

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
      setSuccess("저장했어요. 앱을 연 사용자에게 다음 동기화 시 반영됩니다.");
      onReload();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="page">
      <div className="panel-head">
        <div>
          <h2>푸시 알림 설정</h2>
          <p className="muted sm">
            로컬 예약 알림의 발송 시각·문구를 DB에 저장합니다.
          </p>
        </div>
      </div>

      <div className="info-panel warn">
        <strong>동작 방식 · 제한</strong>
        <ul>
          <li>
            앱은 <strong>로컬 알림</strong>(flutter_local_notifications)만 사용합니다.
            FCM/APNs 원격 푸시가 아닙니다.
          </li>
          <li>
            설정 변경 후 사용자가 <strong>앱을 실행</strong>해야 새 시간·문구로
            재예약됩니다.
          </li>
          <li>
            추천 매장은 앱의 여유로움/약간혼잡 알고리즘으로 정해집니다. 문구의{" "}
            <code>{"{gate}"}</code> 는 매장 구역(정문·중문 등)으로 치환됩니다.
          </li>
          <li>
            앱을 오래 열지 않은 사용자·앱 삭제 사용자에게는 알림을 보낼 수
            없습니다.
          </li>
        </ul>
      </div>

      {error && <div className="alert">{error}</div>}
      {formError && <div className="alert">{formError}</div>}
      {success && <div className="alert success">{success}</div>}

      {loading && !config ? (
        <p className="muted center">불러오는 중…</p>
      ) : (
        <form className="panel form-grid push-form" onSubmit={(e) => void submit(e)}>
          <h3 className="form-section-title">발송 시각 (KST)</h3>

          <label className="field">
            <span className="field-label">점심</span>
            <div className="time-row">
              <input
                type="number"
                min={0}
                max={23}
                value={form.lunchHour}
                onChange={(e) =>
                  patch({ lunchHour: Number.parseInt(e.target.value, 10) || 0 })
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
            <span className="field-label">저녁</span>
            <div className="time-row">
              <input
                type="number"
                min={0}
                max={23}
                value={form.dinnerHour}
                onChange={(e) =>
                  patch({ dinnerHour: Number.parseInt(e.target.value, 10) || 0 })
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

          <label className="field checkbox-field">
            <input
              type="checkbox"
              checked={form.weekdaysOnly}
              onChange={(e) => patch({ weekdaysOnly: e.target.checked })}
            />
            <span>평일만 발송 (월~금)</span>
          </label>

          <label className="field">
            <span className="field-label">미리 예약 일수</span>
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

          <h3 className="form-section-title">알림 문구</h3>

          <label className="field full">
            <span className="field-label">제목 템플릿</span>
            <input
              type="text"
              value={form.titleTemplate}
              onChange={(e) => patch({ titleTemplate: e.target.value })}
              placeholder="{gate}에서 대기 없이 식사할 수 있어요"
            />
            <span className="muted sm">
              미리보기: {previewTitle(form.titleTemplate)}
            </span>
          </label>

          <label className="field full">
            <span className="field-label">본문</span>
            <textarea
              rows={3}
              value={form.bodyTemplate}
              onChange={(e) => patch({ bodyTemplate: e.target.value })}
            />
          </label>

          <div className="push-preview panel inset">
            <p className="muted sm">미리보기</p>
            <strong>{previewTitle(form.titleTemplate)}</strong>
            <p className="push-preview-body">{form.bodyTemplate}</p>
            <p className="muted sm">
              점심 {formatTime(form.lunchHour, form.lunchMinute)} · 저녁{" "}
              {formatTime(form.dinnerHour, form.dinnerMinute)}
              {form.weekdaysOnly ? " · 평일" : " · 매일"}
            </p>
          </div>

          <div className="form-actions full">
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

      <p className="muted sm center">
        SQL 미적용 시 오류 → <code>supabase/push_notification_config.sql</code>{" "}
        실행
      </p>
    </div>
  );
}
