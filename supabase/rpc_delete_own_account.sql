-- 회원 탈퇴 (연관 데이터 정리 + public.users + auth.users 삭제)
-- Dashboard → SQL Editor → Run (users_auth.sql 이후)

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  delete from public.bookmarks where user_id = uid;
  delete from public.notification_settings where user_id = uid;
  delete from public.user_devices where user_id = uid;
  delete from public.crowd_reports where user_id = uid;
  delete from public.analytics_events where user_id = uid;
  delete from public.app_feedback where user_id = uid;

  update public.restaurants set owner_id = null where owner_id = uid;

  delete from public.users where id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
