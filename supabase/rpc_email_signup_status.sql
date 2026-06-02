-- 가입 전 이메일 상태 확인 (앱에서 중복 가입·불필요한 인증 메일 방지)
-- Dashboard → SQL Editor → Run

create or replace function public.email_signup_status(p_email text)
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select case
    when p_email is null or length(trim(p_email)) = 0 then 'invalid'
    when not exists (
      select 1 from auth.users u where lower(u.email) = lower(trim(p_email))
    ) then 'available'
    when exists (
      select 1 from auth.users u
      where lower(u.email) = lower(trim(p_email))
        and u.email_confirmed_at is not null
    ) then 'registered'
    else 'pending'
  end;
$$;

revoke all on function public.email_signup_status(text) from public;
grant execute on function public.email_signup_status(text) to anon, authenticated;
