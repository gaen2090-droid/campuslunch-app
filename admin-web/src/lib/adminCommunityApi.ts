import { supabase } from "./supabase";
import {
  parseBannedWord,
  parseCommunityNoticeAdmin,
  parseCommunityPostAdmin,
  parseCommunityReport,
  type BannedWord,
  type CommunityNoticeAdmin,
  type CommunityPostAdmin,
  type CommunityReport,
} from "../types/community";
import {
  parseCollectionCommentAdmin,
  parseCollectionItem,
  parseRestaurantCollection,
  type CollectionCommentAdmin,
  type CollectionItem,
  type RestaurantCollection,
} from "../types/collection";

export async function fetchCommunityReports(): Promise<CommunityReport[]> {
  const { data, error } = await supabase.rpc("admin_list_community_reports");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseCommunityReport(row as Record<string, unknown>));
}

export async function fetchCommunityPosts(query?: string): Promise<CommunityPostAdmin[]> {
  const { data, error } = await supabase.rpc("admin_list_community_posts", {
    p_limit: 50,
    p_query: query?.trim() || null,
  });
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseCommunityPostAdmin(row as Record<string, unknown>));
}

export async function setCommunityPostPinned(
  id: string,
  pinned: boolean,
): Promise<void> {
  const { error } = await supabase.rpc("admin_set_post_pinned", {
    p_post_id: id,
    p_pinned: pinned,
  });
  if (error) throw error;
}

export async function fetchPinnedPosts(): Promise<CommunityPostAdmin[]> {
  const { data, error } = await supabase.rpc("admin_list_pinned_posts");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseCommunityPostAdmin(row as Record<string, unknown>));
}

export async function reorderPinnedPosts(orderedIds: string[]): Promise<void> {
  const { error } = await supabase.rpc("admin_reorder_pinned_posts", {
    p_post_ids: orderedIds,
  });
  if (error) throw error;
}

export async function setCommunityPostHidden(
  id: string,
  hidden: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("community_posts")
    .update({ is_hidden: hidden })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCommunityPost(id: string, reason: string): Promise<void> {
  const { error } = await supabase.rpc("admin_delete_community_post", {
    p_post_id: id,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function setCommunityCommentHidden(
  id: string,
  hidden: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("community_comments")
    .update({ is_hidden: hidden })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCommunityComment(id: string, reason: string): Promise<void> {
  const { error } = await supabase.rpc("admin_delete_community_comment", {
    p_comment_id: id,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function fetchBannedWords(): Promise<BannedWord[]> {
  const { data, error } = await supabase
    .from("community_banned_words")
    .select("id, word, created_at")
    .order("word", { ascending: true });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map(parseBannedWord);
}

export async function addBannedWord(word: string): Promise<void> {
  const trimmed = word.trim();
  if (!trimmed) return;
  const { error } = await supabase
    .from("community_banned_words")
    .insert({ word: trimmed });
  if (error) throw error;
}

export async function deleteBannedWord(id: string): Promise<void> {
  const { error } = await supabase
    .from("community_banned_words")
    .delete()
    .eq("id", id);
  if (error) throw error;
}

export async function fetchNicknameBannedWords(): Promise<BannedWord[]> {
  const { data, error } = await supabase
    .from("nickname_banned_words")
    .select("id, word, created_at")
    .order("word", { ascending: true });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map(parseBannedWord);
}

export async function addNicknameBannedWord(word: string): Promise<void> {
  const trimmed = word.trim();
  if (!trimmed) return;
  const { error } = await supabase
    .from("nickname_banned_words")
    .insert({ word: trimmed });
  if (error) throw error;
}

export async function deleteNicknameBannedWord(id: string): Promise<void> {
  const { error } = await supabase
    .from("nickname_banned_words")
    .delete()
    .eq("id", id);
  if (error) throw error;
}

export async function fetchNicknameReservedWords(): Promise<BannedWord[]> {
  const { data, error } = await supabase
    .from("nickname_reserved_words")
    .select("id, word, created_at")
    .order("word", { ascending: true });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map(parseBannedWord);
}

export async function addNicknameReservedWord(word: string): Promise<void> {
  const trimmed = word.trim();
  if (!trimmed) return;
  const { error } = await supabase
    .from("nickname_reserved_words")
    .insert({ word: trimmed });
  if (error) throw error;
}

export async function deleteNicknameReservedWord(id: string): Promise<void> {
  const { error } = await supabase
    .from("nickname_reserved_words")
    .delete()
    .eq("id", id);
  if (error) throw error;
}

export async function fetchCommunityNotices(): Promise<CommunityNoticeAdmin[]> {
  const { data, error } = await supabase
    .from("community_notices")
    .select("id, content, is_active, created_at")
    .order("created_at", { ascending: false });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map(parseCommunityNoticeAdmin);
}

export async function createCommunityNotice(content: string): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .insert({ content: content.trim() });
  if (error) throw error;
}

export async function updateCommunityNotice(
  id: string,
  content: string,
): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .update({ content: content.trim() })
    .eq("id", id);
  if (error) throw error;
}

export async function setCommunityNoticeActive(
  id: string,
  active: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .update({ is_active: active })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCommunityNotice(id: string): Promise<void> {
  const { error } = await supabase
    .from("community_notices")
    .delete()
    .eq("id", id);
  if (error) throw error;
}

export async function fetchAdminCollections(): Promise<RestaurantCollection[]> {
  const { data, error } = await supabase.rpc("admin_list_collections");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseRestaurantCollection(row as Record<string, unknown>));
}

export async function createCollection(params: {
  title: string;
  subtitle: string;
  sortOrder: number;
  hashtags: string[];
}): Promise<void> {
  const { error } = await supabase.from("collections").insert({
    title: params.title.trim(),
    subtitle: params.subtitle.trim() || null,
    sort_order: params.sortOrder,
    hashtags: params.hashtags,
  });
  if (error) throw error;
}

export async function updateCollection(
  id: string,
  params: { title: string; subtitle: string; hashtags: string[] },
): Promise<void> {
  const { error } = await supabase
    .from("collections")
    .update({
      title: params.title.trim(),
      subtitle: params.subtitle.trim() || null,
      hashtags: params.hashtags,
    })
    .eq("id", id);
  if (error) throw error;
}

export async function setCollectionPublished(
  id: string,
  published: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("collections")
    .update({ is_published: published })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCollection(id: string, reason: string): Promise<void> {
  const { error } = await supabase.rpc("admin_delete_collection", {
    p_collection_id: id,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function fetchCollectionItems(
  collectionId: string,
): Promise<CollectionItem[]> {
  const { data, error } = await supabase
    .from("collection_items")
    .select("id, collection_id, restaurant_id, note, sort_order, restaurants(name)")
    .eq("collection_id", collectionId)
    .order("sort_order", { ascending: true });
  if (error) throw error;
  if (!data) return [];
  return (data as Record<string, unknown>[]).map((raw) => {
    const restaurant = raw.restaurants as { name?: string } | null;
    return parseCollectionItem({ ...raw, restaurant_name: restaurant?.name ?? null });
  });
}

export async function addCollectionItem(params: {
  collectionId: string;
  restaurantId: string;
  note: string;
  sortOrder: number;
}): Promise<void> {
  const { error } = await supabase.from("collection_items").insert({
    collection_id: params.collectionId,
    restaurant_id: params.restaurantId,
    note: params.note.trim() || null,
    sort_order: params.sortOrder,
  });
  if (error) throw error;
}

export async function removeCollectionItem(id: string): Promise<void> {
  const { error } = await supabase.from("collection_items").delete().eq("id", id);
  if (error) throw error;
}

export async function reorderCollectionItems(
  orderedIds: string[],
): Promise<void> {
  await Promise.all(
    orderedIds.map((id, index) =>
      supabase.from("collection_items").update({ sort_order: index }).eq("id", id),
    ),
  ).then((results) => {
    const failed = results.find((r) => r.error);
    if (failed?.error) throw failed.error;
  });
}

export async function reorderCollections(orderedIds: string[]): Promise<void> {
  await Promise.all(
    orderedIds.map((id, index) =>
      supabase.from("collections").update({ sort_order: index }).eq("id", id),
    ),
  ).then((results) => {
    const failed = results.find((r) => r.error);
    if (failed?.error) throw failed.error;
  });
}

export async function fetchCollectionComments(): Promise<CollectionCommentAdmin[]> {
  const { data, error } = await supabase.rpc("admin_list_collection_comments", {
    p_limit: 100,
  });
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data.map((row) => parseCollectionCommentAdmin(row as Record<string, unknown>));
}

export async function setCollectionCommentHidden(
  id: string,
  hidden: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("collection_comments")
    .update({ is_hidden: hidden })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteCollectionComment(id: string): Promise<void> {
  const { error } = await supabase.from("collection_comments").delete().eq("id", id);
  if (error) throw error;
}

