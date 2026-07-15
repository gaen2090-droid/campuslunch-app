-- 구글/카카오 등 소셜 로그인 유저(이메일이 없거나 auth.users와 불일치)도
-- 삭제할 수 있도록 user id 기준 삭제 RPC를 추가한다.
-- Dashboard → SQL Editor → Run (rpc_admin_users.sql 이후)

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
  delete from public.app_feedback where user_id = p_user_id;
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

create or replace function public.admin_purge_user_by_id(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
begin
  if not public.is_admin() then
    raise exception '관리자만 회원을 삭제할 수 있어요.';
  end if;

  if p_user_id is null then
    raise exception 'user id가 필요해요.';
  end if;

  if not exists (select 1 from public.users u where u.id = p_user_id) then
    return jsonb_build_object('ok', false, 'message', '해당 회원을 찾을 수 없어요.');
  end if;

  if exists (
    select 1 from public.users u
    where u.id = p_user_id and u.role = 'admin'::public.user_role
  ) then
    raise exception '관리자 계정은 삭제할 수 없어요.';
  end if;

  select email into v_email from auth.users where id = p_user_id;

  perform public.purge_user_by_id(p_user_id);

  return jsonb_build_object(
    'ok', true,
    'id', p_user_id,
    'email', v_email,
    'message', '삭제 완료'
  );
end;
$$;

revoke all on function public.admin_purge_user_by_id(uuid) from public;
grant execute on function public.admin_purge_user_by_id(uuid) to authenticated;

select 'admin_purge_user_by_id.sql ok' as status;
