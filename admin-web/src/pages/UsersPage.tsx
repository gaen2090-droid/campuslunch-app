import { useMemo, useState } from "react";
import { Modal } from "../components/Modal";
import { TrustProfileButton } from "../components/TrustUserProfile";
import {
  purgeAdminUserById,
  setCommunitySuspension,
  setReportSuspension,
} from "../lib/adminApi";
import type { BannedWord } from "../types/community";
import { errorMessage } from "../lib/errors";
import { isSuspensionActive, roleLabel, type AdminUser } from "../types/user";

type SuspensionKind = "community" | "report";

interface Props {
  users: AdminUser[];
  nicknameBannedWords: BannedWord[];
  nicknameReservedWords: BannedWord[];
  loading: boolean;
  error: string | null;
  onReload: () => void;
  onAddNicknameWord: (word: string) => Promise<void>;
  onRemoveNicknameWord: (id: string) => Promise<void>;
  onAddReservedWord: (word: string) => Promise<void>;
  onRemoveReservedWord: (id: string) => Promise<void>;
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
  nicknameBannedWords,
  nicknameReservedWords,
  loading,
  error,
  onReload,
  onAddNicknameWord,
  onRemoveNicknameWord,
  onAddReservedWord,
  onRemoveReservedWord,
}: Props) {
  const [query, setQuery] = useState("");
  const [deleteTarget, setDeleteTarget] = useState<AdminUser | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [newNicknameWord, setNewNicknameWord] = useState("");
  const [nicknameWordBusy, setNicknameWordBusy] = useState(false);
  const [nicknameWordBusyId, setNicknameWordBusyId] = useState<string | null>(null);

  const [newReservedWord, setNewReservedWord] = useState("");
  const [reservedWordBusy, setReservedWordBusy] = useState(false);
  const [reservedWordBusyId, setReservedWordBusyId] = useState<string | null>(null);

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
    return users.filter(
      (u) =>
        u.email?.toLowerCase().includes(q) ||
        u.nickname.toLowerCase().includes(q) ||
        u.id.toLowerCase().includes(q),
    );
  }, [users, query]);

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

  async function submitNicknameWord() {
    const word = newNicknameWord.trim();
    if (!word || nicknameWordBusy) return;
    setNicknameWordBusy(true);
    setActionError(null);
    try {
      await onAddNicknameWord(word);
      setNewNicknameWord("");
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setNicknameWordBusy(false);
    }
  }

  async function removeNicknameWord(id: string) {
    setNicknameWordBusyId(id);
    setActionError(null);
    try {
      await onRemoveNicknameWord(id);
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setNicknameWordBusyId(null);
    }
  }

  async function submitReservedWord() {
    const word = newReservedWord.trim();
    if (!word || reservedWordBusy) return;
    setReservedWordBusy(true);
    setActionError(null);
    try {
      await onAddReservedWord(word);
      setNewReservedWord("");
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setReservedWordBusy(false);
    }
  }

  async function removeReservedWord(id: string) {
    setReservedWordBusyId(id);
    setActionError(null);
    try {
      await onRemoveReservedWord(id);
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setReservedWordBusyId(null);
    }
  }

  return (
    <div className="page">
      <div className="panel-head">
        <div>
          <h2>회원 관리</h2>
          <p className="muted sm">
            DB 연관 데이터 + public.users + auth.users 를 함께 삭제합니다.
          </p>
        </div>
        <span className="badge">{users.length}명</span>
      </div>

      <div className="info-panel">
        <strong>주의</strong>
        <ul>
          <li>관리자(role=admin) 계정은 삭제할 수 없어요.</li>
          <li>
            Table Editor / Auth 페이지에서만 지우면 FK 오류가 날 수 있어요.
            여기서 삭제하세요.
          </li>
          <li>
            SQL 미적용 시 오류가 납니다 →{" "}
            <code>supabase/rpc_admin_users.sql</code> 실행
          </li>
        </ul>
      </div>

      {error && <div className="alert">{error}</div>}
      {actionError && <div className="alert">{actionError}</div>}
      {success && <div className="alert success">{success}</div>}

      <input
        className="search-input"
        placeholder="이메일·닉네임·UUID 검색"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />

      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : filtered.length === 0 ? (
        <p className="muted center">표시할 회원이 없어요.</p>
      ) : (
        <ul className="user-list">
          {filtered.map((u) => (
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
              <div
                className="user-row-actions"
                style={{ display: "flex", flexDirection: "column", gap: 6 }}
              >
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

      <div className="panel-head" style={{ marginTop: 32 }}>
        <h2>닉네임 금칙어 관리 (부분 일치)</h2>
      </div>
      <p className="muted sm">
        여기 등록된 단어가 닉네임에 포함되어 있으면 설정할 수 없어요.
        예: &quot;관리자&quot;를 등록하면 &quot;관리자123&quot;도 막혀요.
      </p>
      <div className="row-actions">
        <input
          className="search-input"
          type="text"
          placeholder="추가할 단어 입력"
          value={newNicknameWord}
          onChange={(e) => setNewNicknameWord(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") void submitNicknameWord();
          }}
        />
        <button
          type="button"
          className="btn sm"
          disabled={nicknameWordBusy || !newNicknameWord.trim()}
          onClick={() => void submitNicknameWord()}
        >
          추가
        </button>
      </div>
      {nicknameBannedWords.length === 0 ? (
        <p className="muted center">등록된 금칙어가 없어요.</p>
      ) : (
        <div className="chip-row">
          {nicknameBannedWords.map((w) => (
            <span key={w.id} className="chip">
              {w.word}
              <button
                type="button"
                className="chip-remove"
                disabled={nicknameWordBusyId === w.id}
                onClick={() => void removeNicknameWord(w.id)}
              >
                ×
              </button>
            </span>
          ))}
        </div>
      )}

      <div className="panel-head" style={{ marginTop: 32 }}>
        <h2>닉네임 예약어 관리 (완전 일치)</h2>
      </div>
      <p className="muted sm">
        여기 등록된 단어와 닉네임이 완전히 같을 때만 막아요.
        예: &quot;사용자&quot;를 등록해도 &quot;사용자123&quot;은 허용돼요.
        (시스템이 자동 부여·탈퇴 처리에 쓰는 값이라 원래 등록된 것들은
        지우지 않는 걸 권장해요.)
      </p>
      <div className="row-actions">
        <input
          className="search-input"
          type="text"
          placeholder="추가할 단어 입력"
          value={newReservedWord}
          onChange={(e) => setNewReservedWord(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") void submitReservedWord();
          }}
        />
        <button
          type="button"
          className="btn sm"
          disabled={reservedWordBusy || !newReservedWord.trim()}
          onClick={() => void submitReservedWord()}
        >
          추가
        </button>
      </div>
      {nicknameReservedWords.length === 0 ? (
        <p className="muted center">등록된 예약어가 없어요.</p>
      ) : (
        <div className="chip-row">
          {nicknameReservedWords.map((w) => (
            <span key={w.id} className="chip">
              {w.word}
              <button
                type="button"
                className="chip-remove"
                disabled={reservedWordBusyId === w.id}
                onClick={() => void removeReservedWord(w.id)}
              >
                ×
              </button>
            </span>
          ))}
        </div>
      )}

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
