import { useMemo, useState } from "react";
import { Modal } from "../components/Modal";
import { purgeAdminUserById } from "../lib/adminApi";
import { roleLabel, type AdminUser } from "../types/user";

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

export function UsersPage({ users, loading, error, onReload }: Props) {
  const [query, setQuery] = useState("");
  const [deleteTarget, setDeleteTarget] = useState<AdminUser | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

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
      setActionError(err instanceof Error ? err.message : String(err));
    } finally {
      setDeleteBusy(false);
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
              {u.role !== "admin" && (
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
              )}
            </li>
          ))}
        </ul>
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
    </div>
  );
}
