import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../lib/errors";
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
  fetchPinnedPosts,
  reorderPinnedPosts,
  setCommunityCommentHidden,
  setCommunityNoticeActive,
  setCommunityPostHidden,
  setCommunityPostPinned,
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
  const [pinnedPosts, setPinnedPosts] = useState<CommunityPostAdmin[]>([]);
  const [bannedWords, setBannedWordsState] = useState<BannedWord[]>([]);
  const [notices, setNotices] = useState<CommunityNoticeAdmin[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [postQuery, setPostQuery] = useState("");

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const [reportList, postList, pinnedList, wordList, noticeList] = await Promise.all([
        fetchCommunityReports(),
        fetchCommunityPosts(postQuery),
        fetchPinnedPosts(),
        fetchBannedWords(),
        fetchCommunityNotices(),
      ]);
      setReports(reportList);
      setPosts(postList);
      setPinnedPosts(pinnedList);
      setBannedWordsState(wordList);
      setNotices(noticeList);
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [enabled, postQuery]);

  useEffect(() => {
    if (enabled) void reload();
  }, [enabled, reload]);

  const searchPosts = useCallback(async (query: string) => {
    setPostQuery(query);
    setLoading(true);
    setError(null);
    try {
      setPosts(await fetchCommunityPosts(query));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, []);

  const setPostPinned = useCallback(
    async (id: string, pinned: boolean) => {
      await setCommunityPostPinned(id, pinned);
      await reload();
    },
    [reload],
  );

  const reorderPinned = useCallback(
    async (orderedIds: string[]) => {
      // 낙관적 업데이트 — 드래그 직후 순서가 바로 반영되도록
      setPinnedPosts((prev) => {
        const byId = new Map(prev.map((p) => [p.id, p]));
        return orderedIds.map((id) => byId.get(id)).filter((p): p is CommunityPostAdmin => !!p);
      });
      await reorderPinnedPosts(orderedIds);
      await reload();
    },
    [reload],
  );

  const hidePost = useCallback(
    async (id: string, hidden: boolean) => {
      await setCommunityPostHidden(id, hidden);
      await reload();
    },
    [reload],
  );

  const removePost = useCallback(
    async (id: string, reason: string) => {
      await deleteCommunityPost(id, reason);
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
    async (id: string, reason: string) => {
      await deleteCommunityComment(id, reason);
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
    pinnedPosts,
    bannedWords,
    notices,
    loading,
    error,
    postQuery,
    reload,
    searchPosts,
    hidePost,
    removePost,
    setPostPinned,
    reorderPinned,
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
