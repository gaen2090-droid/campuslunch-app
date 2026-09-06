import { useEffect, useMemo, useState } from "react";

/**
 * 클라이언트 사이드 페이지네이션. 서버는 여전히 전체 목록을 반환하지만
 * (admin_list_users 등 RPC가 페이징을 지원하지 않음), 화면에는 지정한
 * 페이지 크기만큼만 잘라서 보여준다. 목록이 검색/필터로 바뀌면 1페이지로
 * 되돌린다.
 */
export function usePagination<T>(items: T[], pageSize = 25) {
  const [page, setPage] = useState(1);

  const totalPages = Math.max(1, Math.ceil(items.length / pageSize));

  useEffect(() => {
    if (page > totalPages) setPage(1);
  }, [items.length, page, totalPages]);

  const pageItems = useMemo(() => {
    const start = (page - 1) * pageSize;
    return items.slice(start, start + pageSize);
  }, [items, page, pageSize]);

  return {
    page,
    setPage,
    totalPages,
    pageItems,
    totalCount: items.length,
  };
}
