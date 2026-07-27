-- 사장님 통계 배너의 "N일동안 함께하고 있어요" 기준일 — 매장 자체 등록일이 아니라
-- 이 사장님이 이 매장에 대해 승인받은 시점(owner_applications.reviewed_at) 기준.
-- (Dashboard → SQL Editor → Run)

create or replace function public.owner_verified_since(p_restaurant_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select oa.reviewed_at
  from public.owner_applications oa
  where oa.restaurant_id = p_restaurant_id
    and oa.user_id = auth.uid()
    and oa.status = 'approved'
  order by oa.reviewed_at desc
  limit 1;
$$;

grant execute on function public.owner_verified_since(uuid) to authenticated;

select 'owner_verified_since.sql ok' as status;
