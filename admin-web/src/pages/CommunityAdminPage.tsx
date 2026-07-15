import { useState } from "react";
import { DeleteReasonModal } from "../components/DeleteReasonModal";
import type {
  BannedWord,
  CommunityNoticeAdmin,
  CommunityPostAdmin,
  CommunityReport,
} from "../types/community";

interface Props {
  reports: CommunityReport[];
  posts: CommunityPostAdmin[];
  pinnedPosts: CommunityPostAdmin[];
  bannedWords: BannedWord[];
  notices: CommunityNoticeAdmin[];
  loading: boolean;
  error: string | null;
  postQuery: string;
  onSearchPosts: (query: string) => Promise<void>;
  onHidePost: (id: string, hidden: boolean) => Promise<void>;
  onRemovePost: (id: string, reason: string) => Promise<void>;
  onSetPostPinned: (id: string, pinned: boolean) => Promise<void>;
  onReorderPinned: (orderedIds: string[]) => Promise<void>;
  onHideComment: (id: string, hidden: boolean) => Promise<void>;
  onRemoveComment: (id: string, reason: string) => Promise<void>;
  onAddWord: (word: string) => Promise<void>;
  onRemoveWord: (id: string) => Promise<void>;
  onAddNotice: (content: string) => Promise<void>;
  onEditNotice: (id: string, content: string) => Promise<void>;
  onToggleNoticeActive: (id: string, active: boolean) => Promise<void>;
  onRemoveNotice: (id: string) => Promise<void>;
}

function formatDate(d: Date): string {
  return d.toLocaleString("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function CommunityAdminPage({
  reports,
  posts,
  pinnedPosts,
  bannedWords,
  notices,
  loading,
  error,
  postQuery,
  onSearchPosts,
  onHidePost,
  onRemovePost,
  onSetPostPinned,
  onReorderPinned,
  onHideComment,
  onRemoveComment,
  onAddWord,
  onRemoveWord,
  onAddNotice,
  onEditNotice,
  onToggleNoticeActive,
  onRemoveNotice,
}: Props) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [newWord, setNewWord] = useState("");
  const [wordBusy, setWordBusy] = useState(false);
  const [newNotice, setNewNotice] = useState("");
  const [noticeBusy, setNoticeBusy] = useState(false);
  const [postQueryInput, setPostQueryInput] = useState(postQuery);
  const [deleteTarget, setDeleteTarget] = useState<
    { kind: "post" | "comment"; id: string } | null
  >(null);

  async function submitWord() {
    const word = newWord.trim();
    if (!word || wordBusy) return;
    setWordBusy(true);
    setActionError(null);
    try {
      await onAddWord(word);
      setNewWord("");
    } catch (e) {
      setActionError(e instanceof Error ? e.message : String(e));
    } finally {
      setWordBusy(false);
    }
  }

  async function submitNotice() {
    const content = newNotice.trim();
    if (!content || noticeBusy) return;
    setNoticeBusy(true);
    setActionError(null);
    try {
      await onAddNotice(content);
      setNewNotice("");
    } catch (e) {
      setActionError(e instanceof Error ? e.message : String(e));
    } finally {
      setNoticeBusy(false);
    }
  }

  async function run(id: string, fn: () => Promise<void>) {
    setBusyId(id);
    setActionError(null);
    try {
      await fn();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusyId(null);
    }
  }

  async function confirmDelete(reason: string) {
    if (!deleteTarget) return;
    const { kind, id } = deleteTarget;
    await run(id, () =>
      kind === "post" ? onRemovePost(id, reason) : onRemoveComment(id, reason),
    );
    setDeleteTarget(null);
  }

  return (
    <div className="page">
      <div className="panel-head">
        <h2>관리자 공지</h2>
      </div>

      {(error || actionError) && <div className="alert">{error ?? actionError}</div>}

      <div className="field-group">
        <input
          className="search-input"
          type="text"
          placeholder="공지 내용 (커뮤니티 탭 최상단에 노출)"
          value={newNotice}
          onChange={(e) => setNewNotice(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") submitNotice();
          }}
        />
        <button
          type="button"
          className="btn sm"
          disabled={noticeBusy || !newNotice.trim()}
          onClick={submitNotice}
        >
          공지 추가
        </button>
      </div>

      {notices.length === 0 ? (
        <p className="muted center">등록된 공지가 없어요.</p>
      ) : (
        <ul className="feedback-list">
          {notices.map((n) => (
            <NoticeRow
              key={n.id}
              notice={n}
              busy={busyId === n.id}
              onEdit={(content) => onEditNotice(n.id, content)}
              onToggleActive={() => run(n.id, () => onToggleNoticeActive(n.id, !n.isActive))}
              onRemove={() => run(n.id, () => onRemoveNotice(n.id))}
            />
          ))}
        </ul>
      )}

      <div className="panel-head" style={{ marginTop: 32 }}>
        <h2>커뮤니티 신고함</h2>
      </div>

      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : reports.length === 0 ? (
        <p className="muted center">접수된 신고가 없어요.</p>
      ) : (
        <ul className="feedback-list">
          {reports.map((r) => (
            <li key={r.id} className="feedback-row">
              <div className="feedback-row-head">
                <span className="badge">{r.commentId ? "댓글 신고" : "게시글 신고"}</span>
                <span className="muted sm">{formatDate(r.createdAt)}</span>
              </div>
              <p className="muted sm">
                신고자 {r.reporterNickname} · 작성자 {r.authorNickname}
                {r.reason ? ` · 사유: ${r.reason}` : ""}
                {r.isHidden ? " · (이미 숨김)" : ""}
              </p>
              <p className="feedback-content">{r.content}</p>
              <div className="row-actions">
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={busyId === (r.commentId ?? r.postId ?? r.id)}
                  onClick={() =>
                    r.commentId
                      ? run(r.commentId!, () => onHideComment(r.commentId!, !r.isHidden))
                      : run(r.postId!, () => onHidePost(r.postId!, !r.isHidden))
                  }
                >
                  {r.isHidden ? "숨김 해제" : "숨기기"}
                </button>
                <button
                  type="button"
                  className="btn danger sm"
                  disabled={busyId === (r.commentId ?? r.postId ?? r.id)}
                  onClick={() =>
                    setDeleteTarget(
                      r.commentId
                        ? { kind: "comment", id: r.commentId! }
                        : { kind: "post", id: r.postId! },
                    )
                  }
                >
                  삭제
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      <div className="panel-head" style={{ marginTop: 32 }}>
        <h2>공지로 설정한 게시글</h2>
      </div>
      {pinnedPosts.length === 0 ? (
        <p className="muted center">공지로 설정된 게시글이 없어요.</p>
      ) : (
        <ul className="feedback-list">
          {pinnedPosts.map((p, i) => (
            <li key={p.id} className="feedback-row">
              <div className="feedback-row-head">
                <span className="badge assigned">순서 {i + 1}</span>
                <span className="badge">{p.nickname}</span>
                <span className="muted sm">{formatDate(p.createdAt)}</span>
              </div>
              <p className="feedback-content">{p.content}</p>
              <div className="row-actions">
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={busyId === p.id || i === 0}
                  onClick={() => {
                    const ids = pinnedPosts.map((x) => x.id);
                    [ids[i - 1], ids[i]] = [ids[i], ids[i - 1]];
                    run(p.id, () => onReorderPinned(ids));
                  }}
                >
                  위로
                </button>
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={busyId === p.id || i === pinnedPosts.length - 1}
                  onClick={() => {
                    const ids = pinnedPosts.map((x) => x.id);
                    [ids[i + 1], ids[i]] = [ids[i], ids[i + 1]];
                    run(p.id, () => onReorderPinned(ids));
                  }}
                >
                  아래로
                </button>
                <button
                  type="button"
                  className="btn danger sm"
                  disabled={busyId === p.id}
                  onClick={() => run(p.id, () => onSetPostPinned(p.id, false))}
                >
                  공지 해제
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      <div className="panel-head" style={{ marginTop: 32 }}>
        <h2>최근 게시글</h2>
      </div>
      <div className="field-group">
        <input
          className="search-input"
          type="text"
          placeholder="작성자 닉네임 또는 내용 검색"
          value={postQueryInput}
          onChange={(e) => setPostQueryInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") onSearchPosts(postQueryInput);
          }}
        />
        <button
          type="button"
          className="btn sm"
          onClick={() => onSearchPosts(postQueryInput)}
        >
          검색
        </button>
        {postQuery && (
          <button
            type="button"
            className="btn ghost sm"
            onClick={() => {
              setPostQueryInput("");
              onSearchPosts("");
            }}
          >
            초기화
          </button>
        )}
      </div>
      {posts.length === 0 ? (
        <p className="muted center">게시글이 없어요.</p>
      ) : (
        <ul className="feedback-list">
          {posts.map((p) => (
            <li key={p.id} className="feedback-row">
              <div className="feedback-row-head">
                <span className="badge">{p.nickname}</span>
                <span className="muted sm">{formatDate(p.createdAt)}</span>
                {p.isPinned && <span className="badge assigned">공지</span>}
                {p.isHidden && <span className="badge danger">숨김</span>}
              </div>
              <p className="feedback-content">{p.content}</p>
              <p className="muted sm">
                좋아요 {p.likeCount} · 댓글 {p.commentCount}
              </p>
              <div className="row-actions">
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={busyId === p.id}
                  onClick={() => run(p.id, () => onSetPostPinned(p.id, !p.isPinned))}
                >
                  {p.isPinned ? "공지 해제" : "공지로 설정"}
                </button>
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={busyId === p.id}
                  onClick={() => run(p.id, () => onHidePost(p.id, !p.isHidden))}
                >
                  {p.isHidden ? "숨김 해제" : "숨기기"}
                </button>
                <button
                  type="button"
                  className="btn danger sm"
                  disabled={busyId === p.id}
                  onClick={() => setDeleteTarget({ kind: "post", id: p.id })}
                >
                  삭제
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      <div className="panel-head" style={{ marginTop: 32 }}>
        <h2>금칙어 관리</h2>
      </div>
      <div className="row-actions">
        <input
          className="search-input"
          type="text"
          placeholder="추가할 단어 입력"
          value={newWord}
          onChange={(e) => setNewWord(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") submitWord();
          }}
        />
        <button
          type="button"
          className="btn sm"
          disabled={wordBusy || !newWord.trim()}
          onClick={submitWord}
        >
          추가
        </button>
      </div>
      {bannedWords.length === 0 ? (
        <p className="muted center">등록된 금칙어가 없어요.</p>
      ) : (
        <div className="chip-row">
          {bannedWords.map((w) => (
            <span key={w.id} className="chip">
              {w.word}
              <button
                type="button"
                className="chip-remove"
                disabled={busyId === w.id}
                onClick={() => run(w.id, () => onRemoveWord(w.id))}
              >
                ×
              </button>
            </span>
          ))}
        </div>
      )}

      {deleteTarget && (
        <DeleteReasonModal
          title={deleteTarget.kind === "post" ? "게시글 삭제" : "댓글 삭제"}
          onCancel={() => setDeleteTarget(null)}
          onConfirm={confirmDelete}
        />
      )}
    </div>
  );
}

function NoticeRow({
  notice,
  busy,
  onEdit,
  onToggleActive,
  onRemove,
}: {
  notice: CommunityNoticeAdmin;
  busy: boolean;
  onEdit: (content: string) => Promise<void>;
  onToggleActive: () => void;
  onRemove: () => void;
}) {
  const [editing, setEditing] = useState(false);
  const [content, setContent] = useState(notice.content);
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    try {
      await onEdit(content);
      setEditing(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <li className="feedback-row">
      <div className="feedback-row-head">
        <span className={`badge ${notice.isActive ? "assigned" : "danger"}`}>
          {notice.isActive ? "노출중" : "비노출"}
        </span>
        <span className="muted sm">
          {notice.createdAt.toLocaleString("ko-KR", {
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
          })}
        </span>
      </div>

      {editing ? (
        <div className="field-group" style={{ marginTop: 4 }}>
          <input
            className="search-input"
            type="text"
            value={content}
            onChange={(e) => setContent(e.target.value)}
          />
          <button type="button" className="btn sm" disabled={saving} onClick={save}>
            저장
          </button>
          <button
            type="button"
            className="btn ghost sm"
            disabled={saving}
            onClick={() => {
              setContent(notice.content);
              setEditing(false);
            }}
          >
            취소
          </button>
        </div>
      ) : (
        <p className="feedback-content">{notice.content}</p>
      )}

      <div className="row-actions">
        {!editing && (
          <button type="button" className="btn ghost sm" onClick={() => setEditing(true)}>
            수정
          </button>
        )}
        <button type="button" className="btn ghost sm" disabled={busy} onClick={onToggleActive}>
          {notice.isActive ? "비노출로 전환" : "노출하기"}
        </button>
        <button type="button" className="btn danger sm" disabled={busy} onClick={onRemove}>
          삭제
        </button>
      </div>
    </li>
  );
}
