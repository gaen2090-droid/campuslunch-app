export interface RestaurantCollection {
  id: string;
  title: string;
  subtitle: string | null;
  sortOrder: number;
  isPublished: boolean;
  createdAt: Date;
}

export interface CollectionItem {
  id: string;
  collectionId: string;
  restaurantId: string;
  restaurantName: string | null;
  note: string | null;
  sortOrder: number;
}

export function parseRestaurantCollection(
  raw: Record<string, unknown>,
): RestaurantCollection {
  return {
    id: String(raw.id),
    title: String(raw.title ?? ""),
    subtitle: raw.subtitle != null ? String(raw.subtitle) : null,
    sortOrder: Number(raw.sort_order ?? 0) || 0,
    isPublished: Boolean(raw.is_published),
    createdAt: new Date(String(raw.created_at)),
  };
}

export function parseCollectionItem(raw: Record<string, unknown>): CollectionItem {
  return {
    id: String(raw.id),
    collectionId: String(raw.collection_id),
    restaurantId: String(raw.restaurant_id),
    restaurantName: raw.restaurant_name != null ? String(raw.restaurant_name) : null,
    note: raw.note != null ? String(raw.note) : null,
    sortOrder: Number(raw.sort_order ?? 0) || 0,
  };
}

export interface CollectionCommentAdmin {
  id: string;
  collectionId: string;
  collectionTitle: string;
  content: string;
  nickname: string;
  isHidden: boolean;
  createdAt: Date;
}

export function parseCollectionCommentAdmin(
  raw: Record<string, unknown>,
): CollectionCommentAdmin {
  return {
    id: String(raw.id),
    collectionId: String(raw.collection_id),
    collectionTitle: String(raw.collection_title ?? ""),
    content: String(raw.content ?? ""),
    nickname: String(raw.nickname ?? "탈퇴한 사용자"),
    isHidden: Boolean(raw.is_hidden),
    createdAt: new Date(String(raw.created_at)),
  };
}
