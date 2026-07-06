import { useState } from "react";
import type { BannedWord, CommunityPostAdmin, CommunityReport } from "../types/community";

interface Props {
  reports: CommunityReport[];
  posts: CommunityPostAdmin[];
  bannedWords: BannedWord[];
  loading: boolean;
  error: string | null;
  onHidePost: (id: string, hidden: boolean) => Promise<void>;
  onRemovePost: (id: string) => Promise<void>;
  onHideComment: (id: string, hidden: boolean) => Promise<void>;
  onRemoveComment: (id: string) => Promise<void>;
  onAddWord: (word: string) => Promise<void>;
  onRemoveWord: (id: string) => Promise<void>;
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
  bannedWords,
  loading,
  error,
  onHidePost,
  onRemovePost,
  onHideComment,
  onRemoveComment,
  onAddWord,
  onRemoveWord,
}: Props) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [newWord, setNewWord] = useState("");
  const [wordBusy, setWordBusy] = useState(false);

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

  return (
    <div className="page">
      <div className="panel-head">
        <h2>커뮤니티 신고함</h2>
      </div>

      {(error || actionError) && <div className="alert">{error ?? actionError}</div>}

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
                    r.commentId
                      ? run(r.commentId!, () => onRemoveComment(r.commentId!))
                      : run(r.postId!, () => onRemovePost(r.postId!))
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
        <h2>최근 게시글</h2>
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
                  onClick={() => run(p.id, () => onHidePost(p.id, !p.isHidden))}
                >
                  {p.isHidden ? "숨김 해제" : "숨기기"}
                </button>
                <button
                  type="button"
                  className="btn danger sm"
                  disabled={busyId === p.id}
                  onClick={() => run(p.id, () => onRemovePost(p.id))}
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
    </div>
  );
}
