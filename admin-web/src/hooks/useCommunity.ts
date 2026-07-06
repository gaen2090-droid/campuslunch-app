import { useCallback, useEffect, useState } from "react";
import {
  addBannedWord,
  createCommunityNotice,
  deleteBannedWord,
  deleteCommunityComment,
  deleteCommunityNotice,
  deleteCommunityPost,
  fetchBannedWords,
  fetchCommunityNotices,
  fetchCommunityPosts,
  fetchCommunityReports,
  setCommunityCommentHidden,
  setCommunityNoticeActive,
  setCommunityPostHidden,
  updateCommunityNotice,
} from "../lib/adminApi";
import type {
  BannedWord,
  CommunityNoticeAdmin,
  CommunityPostAdmin,
  CommunityReport,
} from "../types/community";

export function useCommunity(enabled: boolean) {
  const [reports, setReports] = useState<CommunityReport[]>([]);
  const [posts, setPosts] = useState<CommunityPostAdmin[]>([]);
  const [bannedWords, setBannedWordsState] = useState<BannedWord[]>([]);
  const [notices, setNotices] = useState<CommunityNoticeAdmin[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const [reportList, postList, wordList, noticeList] = await Promise.all([
        fetchCommunityReports(),
        fetchCommunityPosts(),
        fetchBannedWords(),
        fetchCommunityNotices(),
      ]);
      setReports(reportList);
      setPosts(postList);
      setBannedWordsState(wordList);
      setNotices(noticeList);
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

  const addNotice = useCallback(
    async (content: string) => {
      await createCommunityNotice(content);
      await reload();
    },
    [reload],
  );

  const editNotice = useCallback(
    async (id: string, content: string) => {
      await updateCommunityNotice(id, content);
      await reload();
    },
    [reload],
  );

  const toggleNoticeActive = useCallback(
    async (id: string, active: boolean) => {
      await setCommunityNoticeActive(id, active);
      await reload();
    },
    [reload],
  );

  const removeNotice = useCallback(
    async (id: string) => {
      await deleteCommunityNotice(id);
      await reload();
    },
    [reload],
  );

  return {
    reports,
    posts,
    bannedWords,
    notices,
    loading,
    error,
    reload,
    hidePost,
    removePost,
    hideComment,
    removeComment,
    addNotice,
    editNotice,
    toggleNoticeActive,
    removeNotice,
    addWord,
    removeWord,
  };
}
