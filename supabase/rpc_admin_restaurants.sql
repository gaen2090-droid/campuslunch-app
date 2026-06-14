-- 어드민 매장 관리 (Dashboard → SQL Editor → Run)
-- policies.sql 실행 후 적용. 소프트 삭제 없음 — DELETE 로 DB 행 제거.
--
-- 포함:
--   1) admin_delete_restaurant — 관련 데이터 + restaurants 행 DELETE
--   2) restaurants_select_admin — 어드민은 is_active=false 포함 전체 조회
--   3) restaurants_delete_admin — RPC 없을 때 직접 DELETE 폴백용

-- 구버전 소프트 삭제 함수 제거
drop function if exists public.admin_deactivate_restaurant(uuid);

create or replace function public.admin_delete_restaurant(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  if not exists (
    select 1 from public.restaurants where id = p_restaurant_id
  ) then
    raise exception 'restaurant not found';
  end if;

  delete from public.crowd_reports where restaurant_id = p_restaurant_id;
  delete from public.owner_seat_updates where restaurant_id = p_restaurant_id;
  delete from public.crowd_status where restaurant_id = p_restaurant_id;
  delete from public.analytics_events where restaurant_id = p_restaurant_id;

  delete from public.restaurants where id = p_restaurant_id;

  if not found then
    raise exception 'restaurant delete failed';
  end if;
end;
$$;

revoke all on function public.admin_delete_restaurant(uuid) from public;
grant execute on function public.admin_delete_restaurant(uuid) to authenticated;

-- 어드민: 비활성(is_active=false) 매장 포함 전체 조회
drop policy if exists "restaurants_select_admin" on public.restaurants;
create policy "restaurants_select_admin" on public.restaurants
  for select
  to authenticated
  using (public.is_admin());

-- 어드민: 직접 DELETE (앱/웹 RPC 폴백)
drop policy if exists "restaurants_delete_admin" on public.restaurants;
create policy "restaurants_delete_admin" on public.restaurants
  for delete
  to authenticated
  using (public.is_admin());
