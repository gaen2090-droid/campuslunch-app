-- 이메일로 회원 완전 삭제 (연관 테이블 + public.users + auth.users)
-- Dashboard → SQL Editor → Run (최초 1회)
--
--   select public.purge_user_by_email('test@example.com');
--
-- Table Editor / Auth UI 삭제가 FK 때문에 실패할 때 사용.

create or replace function public.purge_user_by_email(p_email text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid;
begin
  select id into uid
  from auth.users
  where lower(email) = lower(trim(p_email));

  if uid is null then
    raise notice 'auth.users 에 해당 이메일 없음: %', p_email;
    return;
  end if;

  delete from public.bookmarks where user_id = uid;
  delete from public.notification_settings where user_id = uid;
  delete from public.user_devices where user_id = uid;
  delete from public.crowd_reports where user_id = uid;
  delete from public.analytics_events where user_id = uid;
  delete from public.app_feedback where user_id = uid;
  delete from public.owner_seat_updates where owner_id = uid;
  delete from public.user_rewards where user_id = uid;
  update public.gifticons
  set assigned_user_id = null, assigned_at = null
  where assigned_user_id = uid;
  update public.restaurants set owner_id = null where owner_id = uid;

  delete from public.users where id = uid;
  delete from auth.users where id = uid;

  raise notice '삭제 완료: % (id=%)', p_email, uid;
end;
$$;

revoke all on function public.purge_user_by_email(text) from public;
grant execute on function public.purge_user_by_email(text) to service_role;
