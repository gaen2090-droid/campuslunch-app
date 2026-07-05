-- 어드민: 회원 목록 조회 · 완전 삭제
-- Dashboard → SQL Editor → Run (rpc_purge_user_by_email.sql 이후)
--
--   select public.admin_list_users();
--   select public.admin_purge_user_by_email('test@example.com');

create or replace function public.admin_list_users()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t) order by t.created_at desc)
    from (
      select
        u.id,
        u.email,
        u.nickname,
        u.role::text as role,
        u.provider,
        u.created_at,
        u.last_login_at,
        coalesce((
          select count(*)::int
          from public.crowd_reports cr
          where cr.user_id = u.id
        ), 0) as crowd_report_count,
        coalesce(ur.total_stamps, 0) as total_stamps,
        exists (
          select 1 from public.restaurants r where r.owner_id = u.id
        ) as is_owner
      from public.users u
      left join public.user_rewards ur on ur.user_id = u.id
      order by u.created_at desc
    ) t
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_purge_user_by_email(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid;
  target_email text := lower(trim(p_email));
begin
  if not public.is_admin() then
    raise exception '관리자만 회원을 삭제할 수 있어요.';
  end if;

  if target_email is null or target_email = '' or position('@' in target_email) = 0 then
    raise exception '유효한 이메일을 입력해주세요.';
  end if;

  select id into uid
  from auth.users
  where lower(email) = target_email;

  if uid is null then
    return jsonb_build_object('ok', false, 'message', 'auth.users 에 해당 이메일 없음');
  end if;

  if exists (
    select 1 from public.users u
    where u.id = uid and u.role = 'admin'::public.user_role
  ) then
    raise exception '관리자 계정은 삭제할 수 없어요.';
  end if;

  perform public.purge_user_by_email(p_email);

  return jsonb_build_object(
    'ok', true,
    'email', target_email,
    'id', uid,
    'message', '삭제 완료'
  );
end;
$$;

revoke all on function public.admin_list_users() from public;
revoke all on function public.admin_purge_user_by_email(text) from public;
grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_purge_user_by_email(text) to authenticated;
