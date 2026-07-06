import { useCallback, useEffect, useState } from "react";
import {
  addBannedWord,
  deleteBannedWord,
  deleteCommunityComment,
  deleteCommunityPost,
  fetchBannedWords,
  fetchCommunityPosts,
  fetchCommunityReports,
  setCommunityCommentHidden,
  setCommunityPostHidden,
} from "../lib/adminApi";
import type {
  BannedWord,
  CommunityPostAdmin,
  CommunityReport,
} from "../types/community";

export function useCommunity(enabled: boolean) {
  const [reports, setReports] = useState<CommunityReport[]>([]);
  const [posts, setPosts] = useState<CommunityPostAdmin[]>([]);
  const [bannedWords, setBannedWordsState] = useState<BannedWord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const [reportList, postList, wordList] = await Promise.all([
        fetchCommunityReports(),
        fetchCommunityPosts(),
        fetchBannedWords(),
      ]);
      setReports(reportList);
      setPosts(postList);
      setBannedWordsState(wordList);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) void reload();
  }, [enabled, reload]);

  const hidePost = useCallback(
    async (id: string, hidden: boolean) => {
      await setCommunityPostHidden(id, hidden);
      await reload();
    },
    [reload],
  );

  const removePost = useCallback(
    async (id: string) => {
      await deleteCommunityPost(id);
      await reload();
    },
    [reload],
  );

  const hideComment = useCallback(
    async (id: string, hidden: boolean) => {
      await setCommunityCommentHidden(id, hidden);
      await reload();
    },
    [reload],
  );

  const removeComment = useCallback(
    async (id: string) => {
      await deleteCommunityComment(id);
      await reload();
    },
    [reload],
  );

  const addWord = useCallback(
    async (word: string) => {
      await addBannedWord(word);
      await reload();
    },
    [reload],
  );

  const removeWord = useCallback(
    async (id: string) => {
      await deleteBannedWord(id);
      await reload();
    },
    [reload],
  );

  return {
    reports,
    posts,
    bannedWords,
    loading,
    error,
    reload,
    hidePost,
    removePost,
    hideComment,
    removeComment,
    addWord,
    removeWord,
  };
}
