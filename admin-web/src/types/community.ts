export interface CommunityReport {
  id: string;
  reason: string | null;
  createdAt: Date;
  reporterNickname: string;
  postId: string | null;
  commentId: string | null;
  content: string;
  isHidden: boolean;
  authorNickname: string;
  targetPostId: string | null;
}

export interface CommunityPostAdmin {
  id: string;
  content: string;
  imageUrls: string[];
  isHidden: boolean;
  likeCount: number;
  commentCount: number;
  createdAt: Date;
  nickname: string;
}

export function parseCommunityReport(raw: Record<string, unknown>): CommunityReport {
  return {
    id: String(raw.id),
    reason: raw.reason != null ? String(raw.reason) : null,
    createdAt: new Date(String(raw.created_at)),
    reporterNickname: String(raw.reporter_nickname ?? "탈퇴한 사용자"),
    postId: raw.post_id != null ? String(raw.post_id) : null,
    commentId: raw.comment_id != null ? String(raw.comment_id) : null,
    content: String(raw.content ?? ""),
    isHidden: Boolean(raw.is_hidden),
    authorNickname: String(raw.author_nickname ?? "탈퇴한 사용자"),
    targetPostId: raw.target_post_id != null ? String(raw.target_post_id) : null,
  };
}

export interface BannedWord {
  id: string;
  word: string;
  createdAt: Date;
}

export function parseBannedWord(raw: Record<string, unknown>): BannedWord {
  return {
    id: String(raw.id),
    word: String(raw.word ?? ""),
    createdAt: new Date(String(raw.created_at)),
  };
}

export function parseCommunityPostAdmin(raw: Record<string, unknown>): CommunityPostAdmin {
  return {
    id: String(raw.id),
    content: String(raw.content ?? ""),
    imageUrls: Array.isArray(raw.image_urls) ? raw.image_urls.map(String) : [],
    isHidden: Boolean(raw.is_hidden),
    likeCount: Number(raw.like_count ?? 0) || 0,
    commentCount: Number(raw.comment_count ?? 0) || 0,
    createdAt: new Date(String(raw.created_at)),
    nickname: String(raw.nickname ?? "탈퇴한 사용자"),
  };
}
