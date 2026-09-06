import { useState } from "react";
import { errorMessage } from "../lib/errors";
import type { BannedWord } from "../types/community";

interface Props {
  bannedWords: BannedWord[];
  onAddWord: (word: string) => Promise<void>;
  onRemoveWord: (id: string) => Promise<void>;
}

export function CommunityBannedWordsPage({
  bannedWords,
  onAddWord,
  onRemoveWord,
}: Props) {
  const [newWord, setNewWord] = useState("");
  const [wordBusy, setWordBusy] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function submitWord() {
    const word = newWord.trim();
    if (!word || wordBusy) return;
    setWordBusy(true);
    setError(null);
    try {
      await onAddWord(word);
      setNewWord("");
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setWordBusy(false);
    }
  }

  async function removeWord(id: string) {
    setBusyId(id);
    setError(null);
    try {
      await onRemoveWord(id);
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="page">
      <p className="muted sm">
        여기 등록된 단어가 포함된 게시글·댓글은 작성이 차단돼요.
      </p>

      {error && <div className="alert">{error}</div>}

      <div className="row-actions">
        <input
          className="search-input"
          type="text"
          placeholder="추가할 단어 입력"
          value={newWord}
          onChange={(e) => setNewWord(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") void submitWord();
          }}
        />
        <button
          type="button"
          className="btn sm"
          disabled={wordBusy || !newWord.trim()}
          onClick={() => void submitWord()}
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
                onClick={() => void removeWord(w.id)}
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
