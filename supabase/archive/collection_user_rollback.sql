-- 맛집 컬렉션 유저 등록 기능 롤백 (Dashboard → SQL Editor → Run)
-- 앱 UI(FAB, 수정/삭제 메뉴)는 이미 제거됨 — 이 스크립트는 서버 측(RLS·RPC)도
-- 관리자 전용으로 되돌려, API를 직접 호출해도 유저가 컬렉션을 못 만들게 막는다.
-- 나중에 다시 열려면 community_user_collections.sql +
-- community_user_collections_min5.sql + collection_report_count_gate.sql을
-- 순서대로 재실행하면 된다 (git 히스토리에 그대로 남아있음).

-- ── RPC 실행 권한 회수 ──
revoke execute on function public.create_user_collection(text, text, uuid[]) from authenticated;
revoke execute on function public.update_user_collection(uuid, text, text, uuid[]) from authenticated;

-- ── RLS: "본인 컬렉션 쓰기" 제거, 관리자만 쓰기 가능하도록 복원 ──
drop policy if exists "collections owner write" on public.collections;
create policy "collections admin write" on public.collections
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "collection items owner write" on public.collection_items;
create policy "collection items admin write" on public.collection_items
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- select 정책은 유지 — 기존에 유저가 만든 컬렉션도 계속 노출되어야 하므로 손대지 않음
-- (collections read published / collection items read via parent 그대로 유지)

select 'collection_user_rollback.sql ok' as status;
