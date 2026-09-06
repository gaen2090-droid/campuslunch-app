-- 어드민 "회원 완전 삭제" 시 피드백이 함께 사라지는 문제 수정
-- (Dashboard → SQL Editor → Run)
--
-- purge_user_by_id()가 app_feedback을 delete하고 있었다. delete_own_account()
-- (회원 본인 탈퇴)는 같은 테이블을 user_id만 null로 비우는 익명화 방식인데,
-- 어드민의 "완전 삭제"만 실제로 행을 지워서 피드백 내용 자체가 사라졌다.
-- 피드백은 운영 자산이므로 두 경로 모두 보존하도록 맞춘다.

create or replace function public.purge_user_by_id(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if p_user_id is null then
    raise exception 'user id가 필요해요.';
  end if;

  delete from public.bookmarks where user_id = p_user_id;
  delete from public.notification_settings where user_id = p_user_id;
  delete from public.user_devices where user_id = p_user_id;
  delete from public.crowd_reports where user_id = p_user_id;
  delete from public.analytics_events where user_id = p_user_id;
  -- 피드백 내용은 삭제하지 않고 user_id만 비운다 (delete_own_account()와 동일 정책).
  update public.app_feedback set user_id = null where user_id = p_user_id;
  delete from public.owner_seat_updates where owner_id = p_user_id;
  delete from public.user_rewards where user_id = p_user_id;
  update public.gifticons
  set assigned_user_id = null, assigned_at = null
  where assigned_user_id = p_user_id;
  update public.restaurants set owner_id = null where owner_id = p_user_id;

  delete from public.users where id = p_user_id;
  delete from auth.users where id = p_user_id;
end;
$$;

revoke all on function public.purge_user_by_id(uuid) from public;
grant execute on function public.purge_user_by_id(uuid) to service_role;

select 'hotfix_purge_user_preserve_feedback.sql ok' as status;
