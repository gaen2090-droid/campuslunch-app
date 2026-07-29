import { useEffect, useMemo, useState } from "react";
import { DeleteReasonModal } from "../components/DeleteReasonModal";
import type { AdminRestaurant } from "../types/restaurant";
import {
  COLLECTION_HASHTAGS,
  type CollectionCommentAdmin,
  type CollectionItem,
  type RestaurantCollection,
} from "../types/collection";

function HashtagCheckboxes({
  selected,
  onToggle,
}: {
  selected: string[];
  onToggle: (tag: string) => void;
}) {
  return (
    <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
      {COLLECTION_HASHTAGS.map((tag) => (
        <label key={tag} className="chip-toggle">
          <input
            type="checkbox"
            checked={selected.includes(tag)}
            onChange={() => onToggle(tag)}
          />
          #{tag}
        </label>
      ))}
    </div>
  );
}

interface Props {
  restaurants: AdminRestaurant[];
  collections: RestaurantCollection[];
  items: Record<string, CollectionItem[]>;
  comments: CollectionCommentAdmin[];
  loading: boolean;
  error: string | null;
  onAddCollection: (params: {
    title: string;
    subtitle: string;
    sortOrder: number;
    hashtags: string[];
  }) => Promise<void>;
  onEditCollection: (
    id: string,
    params: { title: string; subtitle: string; hashtags: string[] },
  ) => Promise<void>;
  onTogglePublished: (id: string, published: boolean) => Promise<void>;
  onRemoveCollection: (id: string, reason: string) => Promise<void>;
  onAddItem: (params: {
    collectionId: string;
    restaurantId: string;
    note: string;
    sortOrder: number;
  }) => Promise<void>;
  onRemoveItem: (id: string) => Promise<void>;
  onReorderItems: (orderedIds: string[]) => Promise<void>;
  onReorderCollections: (orderedIds: string[]) => Promise<void>;
  onHideComment: (id: string, hidden: boolean) => Promise<void>;
  onRemoveComment: (id: string) => Promise<void>;
}

function formatDate(d: Date): string {
  return d.toLocaleString("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function CollectionsPage({
  restaurants,
  collections,
  items,
  comments,
  loading,
  error,
  onAddCollection,
  onEditCollection,
  onTogglePublished,
  onRemoveCollection,
  onAddItem,
  onRemoveItem,
  onReorderItems,
  onReorderCollections,
  onHideComment,
  onRemoveComment,
}: Props) {
  const [commentBusyId, setCommentBusyId] = useState<string | null>(null);
  const [commentError, setCommentError] = useState<string | null>(null);

  async function runCommentAction(id: string, fn: () => Promise<void>) {
    setCommentBusyId(id);
    setCommentError(null);
    try {
      await fn();
    } catch (e) {
      setCommentError(e instanceof Error ? e.message : String(e));
    } finally {
      setCommentBusyId(null);
    }
  }
  const [newTitle, setNewTitle] = useState("");
  const [newSubtitle, setNewSubtitle] = useState("");
  const [newHashtags, setNewHashtags] = useState<string[]>([]);
  const [creating, setCreating] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [deleteTargetId, setDeleteTargetId] = useState<string | null>(null);

  function toggleNewHashtag(tag: string) {
    setNewHashtags((prev) =>
      prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag],
    );
  }

  const curatedCollections = useMemo(
    () => collections.filter((c) => c.userId == null),
    [collections],
  );
  const userCollections = useMemo(
    () => collections.filter((c) => c.userId != null),
    [collections],
  );

  const [moveBusyId, setMoveBusyId] = useState<string | null>(null);

  async function moveCurated(index: number, direction: -1 | 1) {
    const targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= curatedCollections.length) return;
    const next = [...curatedCollections];
    const [moved] = next.splice(index, 1);
    next.splice(targetIndex, 0, moved);
    setMoveBusyId(curatedCollections[index].id);
    setActionError(null);
    try {
      await onReorderCollections(next.map((c) => c.id));
    } catch (e) {
      setActionError(e instanceof Error ? e.message : String(e));
    } finally {
      setMoveBusyId(null);
    }
  }

  async function submitNewCollection() {
    const title = newTitle.trim();
    if (!title || creating) return;
    setCreating(true);
    setActionError(null);
    try {
      await onAddCollection({
        title,
        subtitle: newSubtitle,
        sortOrder: curatedCollections.length,
        hashtags: newHashtags,
      });
      setNewTitle("");
      setNewSubtitle("");
      setNewHashtags([]);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : String(e));
    } finally {
      setCreating(false);
    }
  }

  return (
    <div className="page">
      <div className="panel-head">
        <h2>맛집 컬렉션</h2>
      </div>

      {(error || actionError) && <div className="alert">{error ?? actionError}</div>}

      <div className="field-group">
        <input
          className="search-input"
          type="text"
          placeholder="컬렉션 제목 (예: 선배들이 추천하는 찐 맛집)"
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
        />
        <input
          className="search-input"
          type="text"
          placeholder="부제(선택)"
          value={newSubtitle}
          onChange={(e) => setNewSubtitle(e.target.value)}
        />
        <button
          type="button"
          className="btn sm"
          disabled={creating || !newTitle.trim()}
          onClick={submitNewCollection}
        >
          컬렉션 추가
        </button>
      </div>
      <div style={{ marginBottom: 16 }}>
        <HashtagCheckboxes selected={newHashtags} onToggle={toggleNewHashtag} />
      </div>

      {loading ? (
        <p className="muted center">불러오는 중…</p>
      ) : collections.length === 0 ? (
        <p className="muted center">등록된 컬렉션이 없어요.</p>
      ) : (
        <>
          {curatedCollections.length > 0 && (
            <p className="muted sm" style={{ marginBottom: 8 }}>
              관리자 큐레이션 (화살표로 노출 순서 변경, 위가 먼저 노출)
            </p>
          )}
          <div style={{ display: "grid", gap: 16 }}>
            {curatedCollections.map((c, index) => (
              <CollectionCard
                key={c.id}
                collection={c}
                items={items[c.id] ?? []}
                restaurants={restaurants}
                busy={busyId === c.id}
                onMoveUp={index > 0 ? () => moveCurated(index, -1) : undefined}
                onMoveDown={
                  index < curatedCollections.length - 1 ? () => moveCurated(index, 1) : undefined
                }
                moveBusy={moveBusyId === c.id}
                onEdit={(params) => onEditCollection(c.id, params)}
                onTogglePublished={(published) => onTogglePublished(c.id, published)}
                onRemove={() => setDeleteTargetId(c.id)}
                onAddItem={(params) => onAddItem({ collectionId: c.id, ...params })}
                onRemoveItem={onRemoveItem}
                onReorderItems={onReorderItems}
              />
            ))}
          </div>

          {userCollections.length > 0 && (
            <>
              <div className="panel-head" style={{ marginTop: 32 }}>
                <h2>유저 작성 컬렉션</h2>
              </div>
              <div style={{ display: "grid", gap: 16 }}>
                {userCollections.map((c) => (
                  <CollectionCard
                    key={c.id}
                    collection={c}
                    items={items[c.id] ?? []}
                    restaurants={restaurants}
                    busy={busyId === c.id}
                    onEdit={(params) => onEditCollection(c.id, params)}
                    onTogglePublished={(published) => onTogglePublished(c.id, published)}
                    onRemove={() => setDeleteTargetId(c.id)}
                    onAddItem={(params) => onAddItem({ collectionId: c.id, ...params })}
                    onRemoveItem={onRemoveItem}
                    onReorderItems={onReorderItems}
                  />
                ))}
              </div>
            </>
          )}
        </>
      )}

      <div className="panel-head" style={{ marginTop: 32 }}>
        <h2>컬렉션 댓글</h2>
      </div>

      {commentError && <div className="alert">{commentError}</div>}

      {comments.length === 0 ? (
        <p className="muted center">등록된 댓글이 없어요.</p>
      ) : (
        <ul className="feedback-list">
          {comments.map((c) => (
            <li key={c.id} className="feedback-row">
              <div className="feedback-row-head">
                <span className={`badge ${c.isHidden ? "danger" : ""}`}>
                  {c.collectionTitle}
                </span>
                <span className="muted sm">{formatDate(c.createdAt)}</span>
              </div>
              <p className="muted sm">{c.nickname}</p>
              <p className="feedback-content">{c.content}</p>
              <div className="row-actions">
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={commentBusyId === c.id}
                  onClick={() => runCommentAction(c.id, () => onHideComment(c.id, !c.isHidden))}
                >
                  {c.isHidden ? "숨김 해제" : "숨기기"}
                </button>
                <button
                  type="button"
                  className="btn danger sm"
                  disabled={commentBusyId === c.id}
                  onClick={() => runCommentAction(c.id, () => onRemoveComment(c.id))}
                >
                  삭제
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {deleteTargetId && (
        <DeleteReasonModal
          title="컬렉션 삭제"
          onCancel={() => setDeleteTargetId(null)}
          onConfirm={async (reason) => {
            setBusyId(deleteTargetId);
            try {
              await onRemoveCollection(deleteTargetId, reason);
              setDeleteTargetId(null);
            } catch (e) {
              setActionError(e instanceof Error ? e.message : String(e));
            } finally {
              setBusyId(null);
            }
          }}
        />
      )}
    </div>
  );
}

function CollectionCard({
  collection,
  items,
  restaurants,
  busy,
  onMoveUp,
  onMoveDown,
  moveBusy,
  onEdit,
  onTogglePublished,
  onRemove,
  onAddItem,
  onRemoveItem,
  onReorderItems,
}: {
  collection: RestaurantCollection;
  items: CollectionItem[];
  restaurants: AdminRestaurant[];
  busy: boolean;
  onMoveUp?: () => void;
  onMoveDown?: () => void;
  moveBusy?: boolean;
  onEdit: (params: { title: string; subtitle: string; hashtags: string[] }) => Promise<void>;
  onTogglePublished: (published: boolean) => Promise<void>;
  onRemove: () => void;
  onAddItem: (params: { restaurantId: string; note: string; sortOrder: number }) => Promise<void>;
  onRemoveItem: (id: string) => Promise<void>;
  onReorderItems: (orderedIds: string[]) => Promise<void>;
}) {
  const [title, setTitle] = useState(collection.title);
  const [subtitle, setSubtitle] = useState(collection.subtitle ?? "");
  const [hashtags, setHashtags] = useState<string[]>(collection.hashtags);
  const [saving, setSaving] = useState(false);

  function toggleHashtag(tag: string) {
    setHashtags((prev) =>
      prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag],
    );
  }
  const [query, setQuery] = useState("");
  const [addBusy, setAddBusy] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);

  const sortedItems = useMemo(
    () => [...items].sort((a, b) => a.sortOrder - b.sortOrder),
    [items],
  );
  const [order, setOrder] = useState<CollectionItem[]>(sortedItems);
  const [orderChanged, setOrderChanged] = useState(false);
  const [orderSaving, setOrderSaving] = useState(false);
  const [dragIndex, setDragIndex] = useState<number | null>(null);

  useEffect(() => {
    if (!orderChanged) setOrder(sortedItems);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sortedItems, orderChanged]);

  function handleDrop(targetIndex: number) {
    if (dragIndex === null || dragIndex === targetIndex) return;
    setOrder((prev) => {
      const next = [...prev];
      const [moved] = next.splice(dragIndex, 1);
      next.splice(targetIndex, 0, moved);
      return next;
    });
    setDragIndex(null);
    setOrderChanged(true);
  }

  async function saveOrder() {
    setOrderSaving(true);
    setLocalError(null);
    try {
      await onReorderItems(order.map((item) => item.id));
      setOrderChanged(false);
    } catch (e) {
      setLocalError(e instanceof Error ? e.message : String(e));
    } finally {
      setOrderSaving(false);
    }
  }

  const usedIds = useMemo(() => new Set(items.map((i) => i.restaurantId)), [items]);
  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return restaurants
      .filter((r) => !usedIds.has(r.id) && r.name.toLowerCase().includes(q))
      .slice(0, 8);
  }, [restaurants, query, usedIds]);

  async function saveEdits() {
    setSaving(true);
    setLocalError(null);
    try {
      await onEdit({ title, subtitle, hashtags });
    } catch (e) {
      setLocalError(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  }

  async function pickRestaurant(r: AdminRestaurant) {
    setAddBusy(true);
    setLocalError(null);
    try {
      await onAddItem({ restaurantId: r.id, note: "", sortOrder: items.length });
      setQuery("");
    } catch (e) {
      setLocalError(e instanceof Error ? e.message : String(e));
    } finally {
      setAddBusy(false);
    }
  }

  return (
    <div className="feedback-row">
      <div className="feedback-row-head">
        {(onMoveUp || onMoveDown) && (
          <span style={{ display: "inline-flex", gap: 2 }}>
            <button
              type="button"
              className="btn ghost sm"
              disabled={!onMoveUp || moveBusy}
              onClick={onMoveUp}
              style={{ padding: "2px 8px" }}
              aria-label="위로 이동"
            >
              ▲
            </button>
            <button
              type="button"
              className="btn ghost sm"
              disabled={!onMoveDown || moveBusy}
              onClick={onMoveDown}
              style={{ padding: "2px 8px" }}
              aria-label="아래로 이동"
            >
              ▼
            </button>
          </span>
        )}
        <span className={`badge ${collection.isPublished ? "assigned" : "danger"}`}>
          {collection.isPublished ? "게시됨" : "비게시"}
        </span>
        <span className="muted sm">매장 {items.length}개</span>
        {collection.userId ? (
          <span className="badge">유저 작성 · {collection.authorNickname ?? "알 수 없음"}</span>
        ) : (
          <span className="muted sm">관리자 큐레이션</span>
        )}
      </div>

      {localError && <div className="alert">{localError}</div>}

      <div className="field-group" style={{ marginTop: 8 }}>
        <input
          className="search-input"
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="제목"
        />
        <input
          className="search-input"
          type="text"
          value={subtitle}
          onChange={(e) => setSubtitle(e.target.value)}
          placeholder="부제"
        />
      </div>

      <div style={{ marginTop: 8, marginBottom: 8 }}>
        <HashtagCheckboxes selected={hashtags} onToggle={toggleHashtag} />
      </div>

      <div className="row-actions">
        <button type="button" className="btn ghost sm" disabled={saving} onClick={saveEdits}>
          저장
        </button>
        <button
          type="button"
          className="btn ghost sm"
          disabled={busy}
          onClick={() => onTogglePublished(!collection.isPublished)}
        >
          {collection.isPublished ? "비게시로 전환" : "게시하기"}
        </button>
        <button type="button" className="btn danger sm" disabled={busy} onClick={onRemove}>
          컬렉션 삭제
        </button>
      </div>

      <div style={{ marginTop: 16 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
          <p className="muted sm">담긴 매장 (드래그로 순서 변경, 왼쪽이 먼저 노출)</p>
          {orderChanged && (
            <button type="button" className="btn sm" disabled={orderSaving} onClick={saveOrder}>
              순서 저장
            </button>
          )}
        </div>
        {order.length === 0 ? (
          <p className="muted sm">아직 담긴 매장이 없어요.</p>
        ) : (
          <div style={{ display: "grid", gap: 6 }}>
            {order.map((item, index) => (
              <div
                key={item.id}
                draggable
                onDragStart={() => setDragIndex(index)}
                onDragOver={(e) => e.preventDefault()}
                onDrop={() => handleDrop(index)}
                className="drag-row"
              >
                <span className="drag-handle">⠿</span>
                <span style={{ flex: 1 }}>{item.restaurantName ?? "알 수 없음"}</span>
                <button
                  type="button"
                  className="btn danger sm"
                  onClick={() => onRemoveItem(item.id)}
                >
                  삭제
                </button>
              </div>
            ))}
          </div>
        )}

        <div style={{ marginTop: 10, position: "relative" }}>
          <input
            className="search-input"
            type="text"
            placeholder="매장 검색해서 추가"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            disabled={addBusy}
          />
          {results.length > 0 && (
            <div className="search-dropdown">
              {results.map((r) => (
                <button
                  type="button"
                  key={r.id}
                  className="search-dropdown-item"
                  onClick={() => pickRestaurant(r)}
                >
                  {r.name}
                  <span className="muted sm"> · {r.area} · {r.category}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
