import { useEffect, useState } from "react";
import {
  cancelScheduledNewsPush,
  createScheduledNewsPush,
  fetchNewsPushReach,
  fetchPushNotificationConfig,
  fetchPushOpsSnapshot,
  fetchScheduledNewsPush,
  invokeNewsPush,
  invokePushEdge,
  updatePushNotificationConfig,
} from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import {
  DEFAULT_PUSH_CONFIG,
  EMPTY_PUSH_OPS,
  formatTime,
  previewCommunityTemplate,
  type NewsPushTarget,
  type PeakPushSchedule,
  type PushNotificationConfig,
  type PushOpsSnapshot,
  type ScheduledNewsPush,
} from "../types/pushConfig";

function targetLabel(target: NewsPushTarget): string {
  return target === "owners_only" ? "사장님만" : "전체";
}

function toLocalDatetimeInputValue(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours(),
  )}:${pad(d.getMinutes())}`;
}

function statusLabel(status: ScheduledNewsPush["status"]): string {
  switch (status) {
    case "pending":
      return "대기중";
    case "sent":
      return "발송완료";
    case "cancelled":
      return "취소됨";
    case "failed":
      return "발송실패";
  }
}

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
  const [savingSection, setSavingSection] = useState<
    "lunch" | "community" | "news" | null
  >(null);
  const [actionBusy, setActionBusy] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [lastRefresh, setLastRefresh] = useState<{
    sent: number;
    failed: number;
  } | null>(null);
  const [newsTitle, setNewsTitle] = useState("");
  const [newsBody, setNewsBody] = useState("");
  const [newsSending, setNewsSending] = useState(false);
  const [newsResult, setNewsResult] = useState<{
    sent: number;
    failed: number;
  } | null>(null);
  const [scheduledList, setScheduledList] = useState<ScheduledNewsPush[]>([]);
  const [scheduledLoading, setScheduledLoading] = useState(false);
  const [scheduleAt, setScheduleAt] = useState("");
  const [scheduling, setScheduling] = useState(false);
  const [cancellingId, setCancellingId] = useState<string | null>(null);
  const [newsTarget, setNewsTarget] = useState<NewsPushTarget>("all");
  const [newsTargetReach, setNewsTargetReach] = useState<{
    users: number;
    devices: number;
  } | null>(null);

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

  async function reloadScheduled() {
    setScheduledLoading(true);
    try {
      setScheduledList(await fetchScheduledNewsPush());
    } catch (err) {
      console.error(err);
    } finally {
      setScheduledLoading(false);
    }
  }

  useEffect(() => {
    void reloadScheduled();
  }, []);

  useEffect(() => {
    let cancelled = false;
    fetchNewsPushReach(newsTarget)
      .then((r) => {
        if (!cancelled) setNewsTargetReach(r);
      })
      .catch((err) => console.error(err));
    return () => {
      cancelled = true;
    };
  }, [newsTarget]);

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

  /**
   * 섹션별 저장: 서버의 최신 설정을 다시 받아온 뒤, 그 위에 이 섹션이 다루는
   * 필드만 로컬 form 값으로 덮어써서 저장한다. 다른 섹션을 편집 중인 동안
   * 이 섹션만 저장해도 서로의 변경을 덮어쓰지 않도록 하기 위함.
   */
  async function saveSection(
    section: "lunch" | "community" | "news",
    overrides: Partial<PushNotificationConfig>,
  ) {
    setSavingSection(section);
    setFormError(null);
    setSuccess(null);
    try {
      const latest = await fetchPushNotificationConfig();
      const merged = { ...latest, ...overrides };
      const saved = await updatePushNotificationConfig(merged);
      setForm(saved);
      setSuccess("저장했어요. 앱은 다음 실행·설정 전파 시 반영됩니다.");
      onReload();
      await reloadOps();
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setSavingSection(null);
    }
  }

  function saveLunchSection() {
    return saveSection("lunch", {
      schedules: form.schedules.slice(0, 1),
      weekdaysOnly: form.weekdaysOnly,
      scheduleDaysAhead: form.scheduleDaysAhead,
      peakFcmEnabled: form.peakFcmEnabled,
      peakLocalScheduleEnabled: form.peakLocalScheduleEnabled,
      peakExcludeOwners: true,
    });
  }

  function saveCommunitySection() {
    return saveSection("community", {
      communityFcmEnabled: form.communityFcmEnabled,
      communityCommentTitleTemplate: form.communityCommentTitleTemplate,
      communityCommentBodyTemplate: form.communityCommentBodyTemplate,
      communityReplyTitleTemplate: form.communityReplyTitleTemplate,
      communityReplyBodyTemplate: form.communityReplyBodyTemplate,
    });
  }

  function saveNewsSection() {
    return saveSection("news", {
      newsFcmEnabled: form.newsFcmEnabled,
      newsExcludeOwners: form.newsExcludeOwners,
    });
  }

  async function runAction(action: string, label: string) {
    setActionBusy(action);
    setFormError(null);
    setSuccess(null);
    try {
      const result = await invokePushEdge(action);
      if (
        action === "config_refresh" &&
        result &&
        typeof result === "object" &&
        "sent" in result
      ) {
        const sent = Number((result as { sent?: unknown }).sent ?? 0);
        const failed = Number((result as { failed?: unknown }).failed ?? 0);
        const pruned = Number((result as { pruned?: unknown }).pruned ?? 0);
        setLastRefresh({ sent, failed });
        setSuccess(
          pruned > 0
            ? `설정 전파 완료 — 성공 ${sent}대 · 실패 ${failed}대 · 무효 토큰 ${pruned}개 삭제`
            : `설정 전파 완료 — 성공 ${sent}대 · 실패 ${failed}대`,
        );
      } else {
        setSuccess(`${label} 완료: ${JSON.stringify(result)}`);
      }
      await reloadOps();
    } catch (err) {
      setFormError(`${label} 실패: ${errorMessage(err)}`);
    } finally {
      setActionBusy(null);
    }
  }

  async function sendNewsPush() {
    const title = newsTitle.trim();
    const body = newsBody.trim();
    if (!title || !body) {
      setFormError("소식 알림 제목/본문을 입력해주세요.");
      return;
    }
    const targetCount = newsTargetReach?.devices ?? 0;
    if (
      !window.confirm(
        `${targetLabel(newsTarget)} 기기 ${targetCount}대에 소식 알림을 보낼까요?\n\n제목: ${title}\n본문: ${body}`,
      )
    ) {
      return;
    }
    setNewsSending(true);
    setFormError(null);
    setSuccess(null);
    try {
      const result = await invokeNewsPush(title, body, newsTarget);
      if (result.skipped) {
        setSuccess(`발송 건너뜀: ${result.skipped}`);
      } else {
        setNewsResult({ sent: result.sent, failed: result.failed });
        setSuccess(`소식 알림 발송 완료 — 성공 ${result.sent} · 실패 ${result.failed}`);
      }
      await reloadOps();
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setNewsSending(false);
    }
  }

  async function scheduleNewsPush() {
    const title = newsTitle.trim();
    const body = newsBody.trim();
    if (!title || !body) {
      setFormError("소식 알림 제목/본문을 입력해주세요.");
      return;
    }
    if (!scheduleAt) {
      setFormError("발송 시각을 선택해주세요.");
      return;
    }
    const at = new Date(scheduleAt);
    if (Number.isNaN(at.getTime()) || at.getTime() <= Date.now()) {
      setFormError("발송 시각은 현재보다 이후여야 해요.");
      return;
    }
    if (
      !window.confirm(
        `${at.toLocaleString("ko-KR")}에 ${targetLabel(newsTarget)} 대상으로 소식 알림을 예약할까요?\n\n제목: ${title}\n본문: ${body}`,
      )
    ) {
      return;
    }
    setScheduling(true);
    setFormError(null);
    setSuccess(null);
    try {
      await createScheduledNewsPush(title, body, at, newsTarget);
      setSuccess("예약했어요. 지정한 시각에 자동으로 발송돼요.");
      setScheduleAt("");
      await reloadScheduled();
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setScheduling(false);
    }
  }

  async function cancelScheduled(id: string) {
    if (!window.confirm("이 예약을 취소할까요?")) return;
    setCancellingId(id);
    setFormError(null);
    try {
      await cancelScheduledNewsPush(id);
      await reloadScheduled();
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setCancellingId(null);
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
          <div>
            <h3 className="push-ops-title">수신 현황</h3>
            <p className="muted sm push-ops-lead">
              서버 FCM 기준 · 알림을 켠 유저 중 <strong>토큰이 있는</strong> 대상만
              집계합니다. (로컬 예약 알림은 폰에서 따로 울립니다)
            </p>
            <p className="muted sm push-landing-note">
              탭 시 이동 위치 — 점심시간 알림: 즐겨찾기 매장 있으면 즐겨찾기
              페이지, 없으면 홈 · 커뮤니티 댓글: 해당 글/모아보기 · 리워드
              지급: 쿠폰함 · 캠퍼스런치 소식: 홈
            </p>
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

        <div className="push-reach-grid">
          <div className="push-reach-card">
            <span className="push-reach-label">점심시간 알림</span>
            <strong className="push-reach-main">{ops.lunchUsers}명</strong>
            <span className="muted sm">기기 {ops.lunchDevices}대</span>
          </div>
          <div className="push-reach-card">
            <span className="push-reach-label">커뮤니티 댓글</span>
            <strong className="push-reach-main">{ops.communityUsers}명</strong>
            <span className="muted sm">기기 {ops.communityDevices}대</span>
          </div>
          <div className="push-reach-card">
            <span className="push-reach-label">리워드 지급</span>
            <strong className="push-reach-main">{ops.rewardUsers}명</strong>
            <span className="muted sm">기기 {ops.rewardDevices}대</span>
          </div>
          <div className="push-reach-card">
            <span className="push-reach-label">캠퍼스런치 소식</span>
            <strong className="push-reach-main">{ops.newsUsers}명</strong>
            <span className="muted sm">기기 {ops.newsDevices}대</span>
          </div>
        </div>

        <div className="push-cost-box">
          <p>
            <strong>설정 전파</strong> 시 전체 등록 토큰{" "}
            <strong>{ops.configRefreshDevices}</strong>건에 data-only 1회씩
            시도합니다. (알림 팝업 없음 · 앱 스케줄 재동기화용)
          </p>
          <p className="muted sm">
            FCM 메시지 발송 <strong>과금 없음</strong> (Firebase 무료 할당량).
            운영에서 볼 지표는 「몇 명/몇 대에 시도하는가」입니다.
            {lastRefresh && (
              <>
                {" "}
                · 최근 전파 성공 {lastRefresh.sent} / 실패 {lastRefresh.failed}
              </>
            )}
          </p>
          {!form.peakFcmEnabled && (
            <p className="muted sm">
              지금 「서버 FCM」이 꺼져 있어 피크 테스트·정기 서버 발송은 나가지
              않습니다. 위 인원은 켰을 때 기준입니다.
            </p>
          )}
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
            최근 서버 피크 발송:{" "}
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
        <div className="panel push-form">
          <section className="push-section">
            <div className="push-section-head row">
              <h3>점심시간 알림</h3>
            </div>
            <p className="muted sm push-landing-note">
              탭 시 이동 위치: 즐겨찾기 매장 있으면 즐겨찾기 페이지, 없으면 홈
            </p>
            <div className="push-section-head row">
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
            <p className="muted sm push-landing-note">
              사장님으로 등록된 계정에는 항상 발송되지 않아요.
            </p>

            <div className="peak-schedule-list">
              {form.schedules.slice(0, 1).map((s, index) => (
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
                  </div>
                  <div className="peak-template-group">
                    <span className="muted sm">
                      개인화용 (즐겨찾기 중 여유로운 매장 있을 때 · {"{restaurant}"} 사용 가능)
                    </span>
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
                  <div className="peak-template-group">
                    <span className="muted sm">
                      고정 홍보용 (즐겨찾기 없거나, 있어도 여유로운 곳 없을 때)
                    </span>
                    <input
                      className="peak-title"
                      type="text"
                      value={s.fallbackTitleTemplate}
                      onChange={(e) =>
                        patchSchedule(index, {
                          fallbackTitleTemplate: e.target.value,
                        })
                      }
                      placeholder="제목"
                    />
                    <textarea
                      className="peak-body"
                      rows={2}
                      value={s.fallbackBodyTemplate}
                      onChange={(e) =>
                        patchSchedule(index, {
                          fallbackBodyTemplate: e.target.value,
                        })
                      }
                      placeholder="본문"
                    />
                  </div>
                </div>
              ))}
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="btn primary sm"
                disabled={savingSection != null}
                onClick={() => void saveLunchSection()}
              >
                {savingSection === "lunch" ? "저장 중…" : "점심시간 설정 저장"}
              </button>
            </div>
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
            <p className="muted sm push-landing-note">
              탭 시 이동 위치: 커뮤니티 탭의 해당 글/모아보기
            </p>

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
              <label className="field">
                <span className="field-label">답글 제목</span>
                <input
                  type="text"
                  value={form.communityReplyTitleTemplate}
                  onChange={(e) =>
                    patch({ communityReplyTitleTemplate: e.target.value })
                  }
                />
                <span className="field-hint">
                  {previewCommunityTemplate(form.communityReplyTitleTemplate)}
                </span>
              </label>
              <label className="field">
                <span className="field-label">답글 본문</span>
                <input
                  type="text"
                  value={form.communityReplyBodyTemplate}
                  onChange={(e) =>
                    patch({ communityReplyBodyTemplate: e.target.value })
                  }
                />
                <span className="field-hint">
                  {previewCommunityTemplate(form.communityReplyBodyTemplate)}
                </span>
              </label>
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="btn primary sm"
                disabled={savingSection != null}
                onClick={() => void saveCommunitySection()}
              >
                {savingSection === "community" ? "저장 중…" : "커뮤니티 설정 저장"}
              </button>
            </div>
          </section>

          <section className="push-section">
            <div className="push-section-head row">
              <h3>캠퍼스런치 소식</h3>
              <label className="chip-toggle">
                <input
                  type="checkbox"
                  checked={form.newsFcmEnabled}
                  onChange={(e) => patch({ newsFcmEnabled: e.target.checked })}
                />
                FCM
              </label>
              <label className="chip-toggle">
                <input
                  type="checkbox"
                  checked={form.newsExcludeOwners}
                  onChange={(e) =>
                    patch({ newsExcludeOwners: e.target.checked })
                  }
                />
                사장님 제외
              </label>
            </div>
            <p className="muted sm">
              업데이트·이벤트 등 운영 소식을 소식 알림에 동의한 유저에게
              보냅니다. "사장님 제외"는 아래 대상을 "전체"로 선택했을 때만
              적용돼요. 아래 "발송"은 즉시 나가고(별도 저장 없이 바로 나가는
              발송이니 신중하게), 시각을 지정하면 그때 한 번만 자동 발송되는
              예약도 가능해요.
            </p>
            <p className="muted sm push-landing-note">
              탭 시 이동 위치: 홈 (매장 지정 없음)
            </p>
            <div className="community-fields">
              <label className="field">
                <span className="field-label">대상</span>
                <select
                  value={newsTarget}
                  onChange={(e) =>
                    setNewsTarget(e.target.value as NewsPushTarget)
                  }
                >
                  <option value="all">전체</option>
                  <option value="owners_only">사장님만</option>
                </select>
                {newsTargetReach && (
                  <span className="field-hint">
                    도달 예상: {newsTargetReach.users}명 · 기기{" "}
                    {newsTargetReach.devices}대
                  </span>
                )}
              </label>
              <label className="field">
                <span className="field-label">제목</span>
                <input
                  type="text"
                  value={newsTitle}
                  onChange={(e) => setNewsTitle(e.target.value)}
                  placeholder="예: 새 기능이 추가됐어요"
                />
              </label>
              <label className="field">
                <span className="field-label">본문</span>
                <input
                  type="text"
                  value={newsBody}
                  onChange={(e) => setNewsBody(e.target.value)}
                  placeholder="예: 지금 확인해보세요 >"
                />
              </label>
            </div>
            <div className="push-ops-actions">
              <button
                type="button"
                className="btn sm"
                disabled={savingSection != null}
                onClick={() => void saveNewsSection()}
              >
                {savingSection === "news" ? "저장 중…" : "소식 FCM 설정 저장"}
              </button>
              <button
                type="button"
                className="btn primary sm"
                disabled={
                  newsSending || !form.newsFcmEnabled || !newsTitle.trim() ||
                  !newsBody.trim()
                }
                onClick={() => void sendNewsPush()}
              >
                {newsSending
                  ? "발송 중…"
                  : `${targetLabel(newsTarget)} 발송 (기기 ${
                      newsTargetReach?.devices ?? 0
                    }대)`}
              </button>
              {!form.newsFcmEnabled && (
                <span className="muted sm">
                  소식 FCM이 꺼져 있어 발송할 수 없어요.
                </span>
              )}
              {newsResult && (
                <span className="muted sm">
                  최근 발송 성공 {newsResult.sent} · 실패 {newsResult.failed}
                </span>
              )}
            </div>

            <div className="push-section-head row" style={{ marginTop: 16 }}>
              <h4 style={{ margin: 0 }}>예약 발송 (일회성)</h4>
            </div>
            <div className="community-fields">
              <label className="field">
                <span className="field-label">발송 시각</span>
                <input
                  type="datetime-local"
                  value={scheduleAt}
                  min={toLocalDatetimeInputValue(new Date())}
                  onChange={(e) => setScheduleAt(e.target.value)}
                />
              </label>
            </div>
            <div className="push-ops-actions">
              <button
                type="button"
                className="btn primary sm"
                disabled={
                  scheduling || !form.newsFcmEnabled || !newsTitle.trim() ||
                  !newsBody.trim() || !scheduleAt
                }
                onClick={() => void scheduleNewsPush()}
              >
                {scheduling ? "예약 중…" : "예약하기"}
              </button>
              {!form.newsFcmEnabled && (
                <span className="muted sm">
                  소식 FCM이 꺼져 있어 예약할 수 없어요.
                </span>
              )}
            </div>

            <div style={{ marginTop: 12 }}>
              {scheduledLoading ? (
                <p className="muted sm">불러오는 중…</p>
              ) : scheduledList.length === 0 ? (
                <p className="muted sm">예약된 소식 알림이 없어요.</p>
              ) : (
                <table className="push-schedule-table">
                  <thead>
                    <tr>
                      <th>발송 시각</th>
                      <th>대상</th>
                      <th>제목</th>
                      <th>본문</th>
                      <th>상태</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {scheduledList.map((item) => (
                      <tr key={item.id}>
                        <td>{item.scheduledAt.toLocaleString("ko-KR")}</td>
                        <td>{targetLabel(item.target)}</td>
                        <td>{item.title}</td>
                        <td>{item.body}</td>
                        <td>{statusLabel(item.status)}</td>
                        <td>
                          {item.status === "pending" && (
                            <button
                              type="button"
                              className="btn sm"
                              disabled={cancellingId === item.id}
                              onClick={() => void cancelScheduled(item.id)}
                            >
                              {cancellingId === item.id ? "취소 중…" : "취소"}
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </section>

          {form.updatedAt && (
            <p className="muted sm push-updated-at">
              마지막 저장: {form.updatedAt.toLocaleString("ko-KR")}
            </p>
          )}
        </div>
      )}
    </div>
  );
}
