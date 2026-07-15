-- 어드민 글/댓글 삭제 → 작성자 FCM용 토큰 조회
-- fcm_push.sql 이후 Run

create or replace function public.list_user_push_tokens(p_user_id uuid)
returns table (token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.token
  from public.user_push_tokens t
  where t.user_id = p_user_id;
$$;

revoke all on function public.list_user_push_tokens(uuid) from public;
grant execute on function public.list_user_push_tokens(uuid) to service_role;

select 'community_moderation_push.sql ok' as status;
