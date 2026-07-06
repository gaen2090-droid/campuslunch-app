import { useCallback, useEffect, useState } from "react";
import {
  addCollectionItem,
  createCollection,
  deleteCollection,
  deleteCollectionComment,
  fetchAdminCollections,
  fetchCollectionComments,
  fetchCollectionItems,
  removeCollectionItem,
  reorderCollectionItems,
  setCollectionCommentHidden,
  setCollectionPublished,
  updateCollection,
} from "../lib/adminApi";
import type {
  CollectionCommentAdmin,
  CollectionItem,
  RestaurantCollection,
} from "../types/collection";

export function useCollections(enabled: boolean) {
  const [collections, setCollections] = useState<RestaurantCollection[]>([]);
  const [items, setItems] = useState<Record<string, CollectionItem[]>>({});
  const [comments, setComments] = useState<CollectionCommentAdmin[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const [list, commentList] = await Promise.all([
        fetchAdminCollections(),
        fetchCollectionComments(),
      ]);
      const itemMap: Record<string, CollectionItem[]> = {};
      for (const c of list) {
        itemMap[c.id] = await fetchCollectionItems(c.id);
      }
      setCollections(list);
      setItems(itemMap);
      setComments(commentList);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (enabled) void reload();
  }, [enabled, reload]);

  const addCollection = useCallback(
    async (params: { title: string; subtitle: string; sortOrder: number }) => {
      await createCollection(params);
      await reload();
    },
    [reload],
  );

  const editCollection = useCallback(
    async (
      id: string,
      params: { title: string; subtitle: string; sortOrder: number },
    ) => {
      await updateCollection(id, params);
      await reload();
    },
    [reload],
  );

  const togglePublished = useCallback(
    async (id: string, published: boolean) => {
      await setCollectionPublished(id, published);
      await reload();
    },
    [reload],
  );

  const removeCollection = useCallback(
    async (id: string) => {
      await deleteCollection(id);
      await reload();
    },
    [reload],
  );

  const addItem = useCallback(
    async (params: {
      collectionId: string;
      restaurantId: string;
      note: string;
      sortOrder: number;
    }) => {
      await addCollectionItem(params);
      await reload();
    },
    [reload],
  );

  const removeItem = useCallback(
    async (id: string) => {
      await removeCollectionItem(id);
      await reload();
    },
    [reload],
  );

  const reorderItems = useCallback(
    async (orderedIds: string[]) => {
      await reorderCollectionItems(orderedIds);
      await reload();
    },
    [reload],
  );

  const hideComment = useCallback(
    async (id: string, hidden: boolean) => {
      await setCollectionCommentHidden(id, hidden);
      await reload();
    },
    [reload],
  );

  const removeComment = useCallback(
    async (id: string) => {
      await deleteCollectionComment(id);
      await reload();
    },
    [reload],
  );

  return {
    collections,
    items,
    comments,
    loading,
    error,
    reload,
    addCollection,
    editCollection,
    togglePublished,
    removeCollection,
    addItem,
    removeItem,
    reorderItems,
    hideComment,
    removeComment,
  };
}
