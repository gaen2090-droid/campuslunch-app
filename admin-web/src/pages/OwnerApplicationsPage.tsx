import { useState } from "react";
import { errorMessage } from "../lib/errors";
import {
  resolveOwnerLicenseUrl,
  reviewOwnerApplication,
} from "../lib/adminApi";
import { Modal } from "../components/Modal";
import {
  ownerApplicationStatusLabel,
  type OwnerApplication,
} from "../types/ownerApplication";

interface Props {
  applications: OwnerApplication[];
  loading: boolean;
  error: string | null;
  onReload: () => void;
}

export function OwnerApplicationsPage({
  applications,
  loading,
  error,
  onReload,
}: Props) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [rejectTarget, setRejectTarget] = useState<OwnerApplication | null>(
    null,
  );
  const [rejectReason, setRejectReason] = useState("");
  const [licenseUrls, setLicenseUrls] = useState<Record<string, string>>({});

  async function loadLicenseUrls(app: OwnerApplication) {
    const missing = app.licensePaths.filter((p) => !licenseUrls[p]);
    if (missing.length === 0) return;
    const entries = await Promise.all(
      missing.map(async (p) => [p, await resolveOwnerLicenseUrl(p)] as const),
    );
    setLicenseUrls((prev) => {
      const next = { ...prev };
      for (const [p, url] of entries) next[p] = url;
      return next;
    });
  }

  async function approve(app: OwnerApplication) {
    setBusyId(app.id);
    setActionError(null);
    try {
      await reviewOwnerApplication(app.id, true);
      onReload();
    } catch (e) {
      setActionError(errorMessage(e));
    } finally {
      setBusyId(null);
    }
  }

  async function confirmReject() {
    if (!rejectTarget) return;
    setBusyId(rejectTarget.id);
    setActionError(null);
    try {
      await reviewOwnerApplication(
        rejectTarget.id,
        false,
        rejectReason.trim() || undefined,
      );
      setRejectTarget(null);
      setRejectReason("");
      onReload();
    } catch (e) {
      setActionError(errorMessage(e));
    } finally {
      setBusyId(null);
    }
  }

  const pending = applications.filter((a) => a.status === "pending");
  const reviewed = applications.filter((a) => a.status !== "pending");

  return (
    <div className="page">
      {(error || actionError) && (
        <div className="alert">{error ?? actionError}</div>
      )}

      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : applications.length === 0 ? (
        <p className="muted center">신청 내역이 없어요.</p>
      ) : (
        <>
          <h3>심사 대기 ({pending.length})</h3>
          {pending.length === 0 ? (
            <p className="muted sm">대기 중인 신청이 없어요.</p>
          ) : (
            <ul className="card-list">
              {pending.map((app) => (
                <li key={app.id} className="card">
                  <div className="card-top">
                    <div>
                      <h3>{app.restaurantName}</h3>
                      <p className="muted sm">
                        신청자 {app.userNickname} · {app.phone} · {app.email}
                      </p>
                      {(app.notifyPush || app.notifySms) && (
                        <p className="muted xs">
                          승인 알림:{" "}
                          {app.notifyPush && (
                            <span className="badge assigned">앱 푸시</span>
                          )}{" "}
                          {app.notifySms && (
                            <span className="badge danger">
                              문자 (승인 시 {app.phone}로 수동 발송 필요)
                            </span>
                          )}
                        </p>
                      )}
                      <p className="muted xs">
                        신청일 {app.createdAt.toLocaleString("ko-KR")}
                      </p>
                      <button
                        type="button"
                        className="link-btn"
                        onClick={() => loadLicenseUrls(app)}
                      >
                        사업자등록증 보기 ({app.licensePaths.length}장)
                      </button>
                      {app.licensePaths.some((p) => licenseUrls[p]) && (
                        <div className="reports-box">
                          {app.licensePaths.map((p) =>
                            licenseUrls[p] ? (
                              <a
                                key={p}
                                href={licenseUrls[p]}
                                target="_blank"
                                rel="noreferrer"
                                className="link-btn"
                              >
                                이미지 열기
                              </a>
                            ) : null,
                          )}
                        </div>
                      )}
                    </div>
                    <div className="card-actions">
                      <button
                        type="button"
                        className="btn primary sm"
                        disabled={busyId === app.id}
                        onClick={() => approve(app)}
                      >
                        승인
                      </button>
                      <button
                        type="button"
                        className="btn danger sm"
                        disabled={busyId === app.id}
                        onClick={() => setRejectTarget(app)}
                      >
                        반려
                      </button>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}

          <h3>심사 완료 ({reviewed.length})</h3>
          {reviewed.length === 0 ? (
            <p className="muted sm">처리된 신청이 없어요.</p>
          ) : (
            <ul className="card-list">
              {reviewed.map((app) => (
                <li key={app.id} className="card">
                  <div className="card-top">
                    <div>
                      <div className="card-title-row">
                        <h3>{app.restaurantName}</h3>
                        <span className={`badge ${app.status}`}>
                          {ownerApplicationStatusLabel(app.status)}
                        </span>
                      </div>
                      <p className="muted sm">
                        신청자 {app.userNickname} · {app.phone} · {app.email}
                      </p>
                      {(app.notifyPush || app.notifySms) && (
                        <p className="muted xs">
                          승인 알림:{" "}
                          {app.notifyPush && (
                            <span className="badge assigned">앱 푸시</span>
                          )}{" "}
                          {app.notifySms && (
                            <span className="badge danger">
                              문자 ({app.phone})
                            </span>
                          )}
                        </p>
                      )}
                      {app.rejectReason && (
                        <p className="muted sm">반려 사유: {app.rejectReason}</p>
                      )}
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </>
      )}

      {rejectTarget && (
        <Modal
          title="사장님 인증 반려"
          onClose={() => {
            setRejectTarget(null);
            setRejectReason("");
          }}
        >
          <p>
            <strong>{rejectTarget.restaurantName}</strong> ·{" "}
            {rejectTarget.userNickname}
          </p>
          <label className="field">
            <span className="field-label">반려 사유</span>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="예: 사업자등록증 사진이 흐려요. 다시 촬영해 첨부해주세요."
              rows={3}
            />
          </label>
          <div className="modal-actions">
            <button
              type="button"
              className="btn ghost"
              disabled={busyId === rejectTarget.id}
              onClick={() => {
                setRejectTarget(null);
                setRejectReason("");
              }}
            >
              취소
            </button>
            <button
              type="button"
              className="btn danger"
              disabled={busyId === rejectTarget.id}
              onClick={confirmReject}
            >
              {busyId === rejectTarget.id ? "처리 중…" : "반려하기"}
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}
