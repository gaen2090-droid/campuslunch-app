-- 어드민 피드백 목록에 "사장님이 보낸 피드백인지" 표시 (Dashboard → SQL Editor → Run)
-- app_feedback은 user_id만 저장하므로, 조회 시 restaurants.owner_id를 조인해
-- is_from_owner를 함께 반환하는 RPC를 추가한다.

create or replace function public.admin_list_feedback()
returns table (
  id            uuid,
  category      text,
  content       text,
  user_id       uuid,
  nickname      text,
  is_from_owner boolean,
  created_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    f.id,
    f.category,
    f.content,
    f.user_id,
    u.nickname,
    exists (
      select 1 from public.restaurants r
      where r.owner_id = f.user_id and r.is_active
    ) as is_from_owner,
    f.created_at
  from public.app_feedback f
  left join public.users u on u.id = f.user_id
  where public.is_admin()
  order by f.created_at desc;
$$;

revoke all on function public.admin_list_feedback() from public;
grant execute on function public.admin_list_feedback() to authenticated;

select 'feedback_owner_flag.sql ok' as status;
