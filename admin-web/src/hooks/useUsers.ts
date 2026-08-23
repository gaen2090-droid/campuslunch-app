import { useCallback, useEffect, useState } from "react";
import {
  addNicknameBannedWord,
  deleteNicknameBannedWord,
  fetchAdminUsers,
  fetchNicknameBannedWords,
} from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import type { BannedWord } from "../types/community";
import type { AdminUser } from "../types/user";

export function useUsers(enabled: boolean) {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [nicknameBannedWords, setNicknameBannedWords] = useState<BannedWord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const [userList, wordList] = await Promise.all([
        fetchAdminUsers(),
        fetchNicknameBannedWords(),
      ]);
      setUsers(userList);
      setNicknameBannedWords(wordList);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const addNicknameWord = useCallback(
    async (word: string) => {
      await addNicknameBannedWord(word);
      await reload();
    },
    [reload],
  );

  const removeNicknameWord = useCallback(
    async (id: string) => {
      await deleteNicknameBannedWord(id);
      await reload();
    },
    [reload],
  );

  return {
    users,
    nicknameBannedWords,
    loading,
    error,
    reload,
    addNicknameWord,
    removeNicknameWord,
  };
}
