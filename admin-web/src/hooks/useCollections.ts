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
  reorderCollections,
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

  const reload = useCallback(
    async (opts?: { silent?: boolean }) => {
      if (!enabled) return;
      if (!opts?.silent) setLoading(true);
      setError(null);
      try {
        const [list, commentList] = await Promise.all([
          fetchAdminCollections(),
          fetchCollectionComments(),
        ]);
        const itemLists = await Promise.all(
          list.map((c) => fetchCollectionItems(c.id)),
        );
        const itemMap: Record<string, CollectionItem[]> = {};
        list.forEach((c, i) => {
          itemMap[c.id] = itemLists[i];
        });
        setCollections(list);
        setItems(itemMap);
        setComments(commentList);
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      } finally {
        if (!opts?.silent) setLoading(false);
      }
    },
    [enabled],
  );

  useEffect(() => {
    if (enabled) void reload();
  }, [enabled, reload]);

  const addCollection = useCallback(
    async (params: {
      title: string;
      subtitle: string;
      sortOrder: number;
      hashtags: string[];
    }) => {
      await createCollection(params);
      await reload({ silent: true });
    },
    [reload],
  );

  const editCollection = useCallback(
    async (
      id: string,
      params: { title: string; subtitle: string; hashtags: string[] },
    ) => {
      await updateCollection(id, params);
      await reload({ silent: true });
    },
    [reload],
  );

  const togglePublished = useCallback(
    async (id: string, published: boolean) => {
      await setCollectionPublished(id, published);
      await reload({ silent: true });
    },
    [reload],
  );

  const removeCollection = useCallback(
    async (id: string, reason: string) => {
      await deleteCollection(id, reason);
      await reload({ silent: true });
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
      await reload({ silent: true });
    },
    [reload],
  );

  const removeItem = useCallback(
    async (id: string) => {
      await removeCollectionItem(id);
      await reload({ silent: true });
    },
    [reload],
  );

  const reorderItems = useCallback(
    async (orderedIds: string[]) => {
      await reorderCollectionItems(orderedIds);
      await reload({ silent: true });
    },
    [reload],
  );

  const reorderCollectionsList = useCallback(
    async (orderedIds: string[]) => {
      await reorderCollections(orderedIds);
      await reload({ silent: true });
    },
    [reload],
  );

  const hideComment = useCallback(
    async (id: string, hidden: boolean) => {
      await setCollectionCommentHidden(id, hidden);
      await reload({ silent: true });
    },
    [reload],
  );

  const removeComment = useCallback(
    async (id: string) => {
      await deleteCollectionComment(id);
      await reload({ silent: true });
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
    reorderCollectionsList,
    hideComment,
    removeComment,
  };
}
