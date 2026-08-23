import { useCallback, useEffect, useState } from "react";
import {
  addNicknameBannedWord,
  addNicknameReservedWord,
  deleteNicknameBannedWord,
  deleteNicknameReservedWord,
  fetchAdminUsers,
  fetchNicknameBannedWords,
  fetchNicknameReservedWords,
} from "../lib/adminApi";
import { errorMessage } from "../lib/errors";
import type { BannedWord } from "../types/community";
import type { AdminUser } from "../types/user";

export function useUsers(enabled: boolean) {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [nicknameBannedWords, setNicknameBannedWords] = useState<BannedWord[]>([]);
  const [nicknameReservedWords, setNicknameReservedWords] = useState<BannedWord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const [userList, bannedList, reservedList] = await Promise.all([
        fetchAdminUsers(),
        fetchNicknameBannedWords(),
        fetchNicknameReservedWords(),
      ]);
      setUsers(userList);
      setNicknameBannedWords(bannedList);
      setNicknameReservedWords(reservedList);
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

  const addReservedWord = useCallback(
    async (word: string) => {
      await addNicknameReservedWord(word);
      await reload();
    },
    [reload],
  );

  const removeReservedWord = useCallback(
    async (id: string) => {
      await deleteNicknameReservedWord(id);
      await reload();
    },
    [reload],
  );

  return {
    users,
    nicknameBannedWords,
    nicknameReservedWords,
    loading,
    error,
    reload,
    addNicknameWord,
    removeNicknameWord,
    addReservedWord,
    removeReservedWord,
  };
}
