import { useState } from "react";
import { errorMessage } from "../lib/errors";
import type { BannedWord } from "../types/community";

interface Props {
  nicknameBannedWords: BannedWord[];
  nicknameReservedWords: BannedWord[];
  onAddNicknameWord: (word: string) => Promise<void>;
  onRemoveNicknameWord: (id: string) => Promise<void>;
  onAddReservedWord: (word: string) => Promise<void>;
  onRemoveReservedWord: (id: string) => Promise<void>;
}

export function NicknameWordsPage({
  nicknameBannedWords,
  nicknameReservedWords,
  onAddNicknameWord,
  onRemoveNicknameWord,
  onAddReservedWord,
  onRemoveReservedWord,
}: Props) {
  const [newNicknameWord, setNewNicknameWord] = useState("");
  const [nicknameWordBusy, setNicknameWordBusy] = useState(false);
  const [nicknameWordBusyId, setNicknameWordBusyId] = useState<string | null>(
    null,
  );

  const [newReservedWord, setNewReservedWord] = useState("");
  const [reservedWordBusy, setReservedWordBusy] = useState(false);
  const [reservedWordBusyId, setReservedWordBusyId] = useState<string | null>(
    null,
  );

  const [error, setError] = useState<string | null>(null);

  async function submitNicknameWord() {
    const word = newNicknameWord.trim();
    if (!word || nicknameWordBusy) return;
    setNicknameWordBusy(true);
    setError(null);
    try {
      await onAddNicknameWord(word);
      setNewNicknameWord("");
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setNicknameWordBusy(false);
    }
  }

  async function removeNicknameWord(id: string) {
    setNicknameWordBusyId(id);
    setError(null);
    try {
      await onRemoveNicknameWord(id);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setNicknameWordBusyId(null);
    }
  }

  async function submitReservedWord() {
    const word = newReservedWord.trim();
    if (!word || reservedWordBusy) return;
    setReservedWordBusy(true);
    setError(null);
    try {
      await onAddReservedWord(word);
      setNewReservedWord("");
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setReservedWordBusy(false);
    }
  }

  async function removeReservedWord(id: string) {
    setReservedWordBusyId(id);
    setError(null);
    try {
      await onRemoveReservedWord(id);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setReservedWordBusyId(null);
    }
  }

  return (
    <div className="page">
      {error && <div className="alert">{error}</div>}

      <div className="panel-head">
        <h3>닉네임 금칙어 (부분 일치)</h3>
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

      <div className="panel-head mt-8">
        <h3>닉네임 예약어 (완전 일치)</h3>
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
    </div>
  );
}
