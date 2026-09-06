import { useMemo, useState } from "react";
import { Modal } from "../components/Modal";
import { Pagination } from "../components/Pagination";
import { TrustProfileButton } from "../components/TrustUserProfile";
import { usePagination } from "../hooks/usePagination";
import {
  purgeAdminUserById,
  setCommunitySuspension,
  setReportSuspension,
} from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import { isSuspensionActive, roleLabel, type AdminUser } from "../types/user";

type SuspensionKind = "community" | "report";

interface Props {
  users: AdminUser[];
  loading: boolean;
  error: string | null;
  onReload: () => void;
}

function formatDate(d: Date | null): string {
  if (!d || Number.isNaN(d.getTime())) return "-";
  return d.toLocaleString("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function UsersPage({
  users,
  loading,
  error,
  onReload,
}: Props) {
  const [query, setQuery] = useState("");
  const [deleteTarget, setDeleteTarget] = useState<AdminUser | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [suspendTarget, setSuspendTarget] = useState<{
    user: AdminUser;
    kind: SuspensionKind;
  } | null>(null);
  const [suspendDays, setSuspendDays] = useState("7");
  const [suspendReason, setSuspendReason] = useState("");
  const [suspendBusy, setSuspendBusy] = useState(false);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return users;
    // "사장님"/"오너"로 검색하면 매장 소유 인증된 회원만 걸러서 보여준다.
    if (q === "사장님" || q === "오너" || q === "owner") {
      return users.filter((u) => u.isOwner);
    }
    return users.filter(
      (u) =>
        u.email?.toLowerCase().includes(q) ||
        u.nickname.toLowerCase().includes(q) ||
        u.id.toLowerCase().includes(q),
    );
  }, [users, query]);

  const { page, setPage, totalPages, pageItems } = usePagination(filtered, 25);

  async function confirmDelete() {
    if (!deleteTarget) return;
    setDeleteBusy(true);
    setActionError(null);
    try {
      const msg = await purgeAdminUserById(deleteTarget.id);
      setSuccess(`${deleteTarget.email ?? deleteTarget.nickname} — ${msg}`);
      setDeleteTarget(null);
      onReload();
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setDeleteBusy(false);
    }
  }

  function openSuspend(user: AdminUser, kind: SuspensionKind) {
    setActionError(null);
    setSuccess(null);
    setSuspendDays("7");
    setSuspendReason("");
    setSuspendTarget({ user, kind });
  }

  async function confirmSuspend() {
    if (!suspendTarget) return;
    const days = Number.parseInt(suspendDays, 10);
    if (!Number.isFinite(days) || days <= 0) {
      setActionError("정지 기간(일)을 1 이상으로 입력해주세요.");
      return;
    }
    setSuspendBusy(true);
    setActionError(null);
    try {
      const fn =
        suspendTarget.kind === "community"
          ? setCommunitySuspension
          : setReportSuspension;
      await fn(suspendTarget.user.id, days, suspendReason.trim());
      const label = suspendTarget.kind === "community" ? "커뮤니티" : "제보";
      setSuccess(
        `${suspendTarget.user.nickname}님의 ${label} 이용을 ${days}일간 정지했어요.`,
      );
      setSuspendTarget(null);
      onReload();
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setSuspendBusy(false);
    }
  }

  async function unsuspend(user: AdminUser, kind: SuspensionKind) {
    setActionError(null);
    setSuccess(null);
    try {
      const fn = kind === "community" ? setCommunitySuspension : setReportSuspension;
      await fn(user.id, 0, "");
      const label = kind === "community" ? "커뮤니티" : "제보";
      setSuccess(`${user.nickname}님의 ${label} 정지를 해제했어요.`);
      onReload();
    } catch (err) {
      setActionError(errorMessage(err));
    }
  }

  return (
    <div className="page">
      <div className="panel-head">
        <span className="badge">{users.length}명</span>
      </div>

      {error && <div className="alert">{error}</div>}
      {actionError && <div className="alert">{actionError}</div>}
      {success && <div className="alert success">{success}</div>}

      <input
        className="search-input"
        placeholder="이메일·닉네임·UUID 검색 (또는 '사장님' 입력)"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />

      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : filtered.length === 0 ? (
        <p className="muted center">표시할 회원이 없어요.</p>
      ) : (
        <ul className="user-list">
          {pageItems.map((u) => (
            <li key={u.id} className="user-row">
              <div className="user-row-main">
                <div className="user-row-head">
                  <strong>{u.nickname}</strong>
                  <span className={`badge role-${u.role}`}>{roleLabel(u.role)}</span>
                  {u.isOwner && <span className="badge owner">매장 소유</span>}
                  {isSuspensionActive(u.communitySuspendedUntil) && (
                    <span className="badge danger-text">
                      커뮤니티 정지 ~{formatDate(u.communitySuspendedUntil)}
                    </span>
                  )}
                  {isSuspensionActive(u.reportSuspendedUntil) && (
                    <span className="badge danger-text">
                      제보 정지 ~{formatDate(u.reportSuspendedUntil)}
                    </span>
                  )}
                </div>
                <p className="user-email">{u.email ?? "(이메일 없음)"}</p>
                <p className="muted sm mono">{u.id}</p>
                <div className="user-meta">
                  <span>가입 {formatDate(u.createdAt)}</span>
                  <span>최근 로그인 {formatDate(u.lastLoginAt)}</span>
                  <span>제보 {u.crowdReportCount}건</span>
                  <span>스탬프 {u.totalStamps}</span>
                  {u.provider && <span>{u.provider}</span>}
                </div>
              </div>
              <div className="user-row-actions">
                <TrustProfileButton userId={u.id} nickname={u.nickname} />
                {u.role !== "admin" && (
                  <>
                    {isSuspensionActive(u.communitySuspendedUntil) ? (
                      <button
                        type="button"
                        className="btn ghost sm"
                        onClick={() => void unsuspend(u, "community")}
                      >
                        커뮤니티 정지 해제
                      </button>
                    ) : (
                      <button
                        type="button"
                        className="btn ghost sm"
                        onClick={() => openSuspend(u, "community")}
                      >
                        커뮤니티 정지
                      </button>
                    )}
                    {isSuspensionActive(u.reportSuspendedUntil) ? (
                      <button
                        type="button"
                        className="btn ghost sm"
                        onClick={() => void unsuspend(u, "report")}
                      >
                        제보 정지 해제
                      </button>
                    ) : (
                      <button
                        type="button"
                        className="btn ghost sm"
                        onClick={() => openSuspend(u, "report")}
                      >
                        제보 정지
                      </button>
                    )}
                    <button
                      type="button"
                      className="btn danger sm"
                      onClick={() => {
                        setSuccess(null);
                        setActionError(null);
                        setDeleteTarget(u);
                      }}
                    >
                      완전 삭제
                    </button>
                  </>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}

      <Pagination page={page} totalPages={totalPages} onChange={setPage} />

      {deleteTarget && (
        <Modal
          title="회원 완전 삭제"
          onClose={() => !deleteBusy && setDeleteTarget(null)}
        >
          <p>
            <strong>{deleteTarget.email}</strong> ({deleteTarget.nickname})
            계정과 연관 데이터를 모두 삭제할까요?
          </p>
          <p className="muted sm">
            북마크·제보·스탬프·기프티콘 배정·사장님 매장 연결 등이 정리됩니다.
            되돌릴 수 없어요.
          </p>
          <div className="modal-actions">
            <button
              type="button"
              className="btn ghost"
              disabled={deleteBusy}
              onClick={() => setDeleteTarget(null)}
            >
              취소
            </button>
            <button
              type="button"
              className="btn danger"
              disabled={deleteBusy}
              onClick={() => void confirmDelete()}
            >
              {deleteBusy ? "삭제 중…" : "삭제"}
            </button>
          </div>
        </Modal>
      )}

      {suspendTarget && (
        <Modal
          title={
            suspendTarget.kind === "community" ? "커뮤니티 이용 정지" : "제보 이용 정지"
          }
          onClose={() => !suspendBusy && setSuspendTarget(null)}
        >
          <p>
            <strong>{suspendTarget.user.nickname}</strong>
            {" "}
            (
            {suspendTarget.user.email ?? "이메일 없음"}
            )
          </p>
          <p className="muted sm">
            {suspendTarget.kind === "community"
              ? "정지 기간 동안 게시글·댓글 작성이 막혀요."
              : "정지 기간 동안 혼잡도 제보가 막혀요."}
          </p>
          <label className="field">
            <span className="field-label">정지 기간(일)</span>
            <input
              type="number"
              min={1}
              step={1}
              value={suspendDays}
              onChange={(e) => setSuspendDays(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="field-label">사유 (선택)</span>
            <input
              placeholder="예: 반복 신고 누적"
              value={suspendReason}
              onChange={(e) => setSuspendReason(e.target.value)}
            />
          </label>
          <div className="modal-actions">
            <button
              type="button"
              className="btn ghost"
              disabled={suspendBusy}
              onClick={() => setSuspendTarget(null)}
            >
              취소
            </button>
            <button
              type="button"
              className="btn danger"
              disabled={suspendBusy}
              onClick={() => void confirmSuspend()}
            >
              {suspendBusy ? "처리 중…" : "정지"}
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}
