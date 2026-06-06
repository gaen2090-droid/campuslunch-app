-- OAuth(google/kakao 등) 로그인 전 이메일 충돌 확인
-- 이메일·비밀번호로 가입 완료된 계정과 동일 Gmail → 소셜 로그인 차단
-- Dashboard → SQL Editor → Run

create or replace function public.oauth_login_email_check(
  p_email text,
  p_provider text
)
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select case
    when p_email is null or length(trim(p_email)) = 0 then 'invalid'
    when p_provider is null or length(trim(p_provider)) = 0 then 'invalid'
    when not exists (
      select 1 from auth.users u
      where lower(u.email) = lower(trim(p_email))
    ) then 'available'
    when exists (
      select 1 from auth.users u
      where lower(u.email) = lower(trim(p_email))
        and u.email_confirmed_at is null
    ) then 'pending'
    when exists (
      select 1 from auth.users u
      inner join auth.identities i on i.user_id = u.id
      where lower(u.email) = lower(trim(p_email))
        and u.email_confirmed_at is not null
        and i.provider = trim(p_provider)
    ) then 'same_provider'
    when exists (
      select 1 from auth.users u
      where lower(u.email) = lower(trim(p_email))
        and u.email_confirmed_at is not null
        and exists (
          select 1 from auth.identities i
          where i.user_id = u.id and i.provider = 'email'
        )
    ) then 'blocked_email'
    else 'blocked_other'
  end;
$$;

revoke all on function public.oauth_login_email_check(text, text) from public;
grant execute on function public.oauth_login_email_check(text, text) to anon, authenticated;
