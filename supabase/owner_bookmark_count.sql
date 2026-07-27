-- 사장님 통계 화면의 "누적 즐겨찾기 수" — 본인 매장만 조회 가능 (Dashboard → SQL Editor → Run)

create or replace function public.owner_restaurant_bookmark_count(p_restaurant_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.bookmarks b
  where b.restaurant_id = p_restaurant_id
    and exists (
      select 1 from public.restaurants r
      where r.id = p_restaurant_id
        and r.owner_id = auth.uid()
    );
$$;

grant execute on function public.owner_restaurant_bookmark_count(uuid) to authenticated;

select 'owner_bookmark_count.sql ok' as status;
