-- 닉네임 중복 방지 (대소문자·앞뒤 공백 무시)
-- Dashboard → SQL Editor → Run (rpc_nickname_available.sql 이후)

create unique index if not exists users_nickname_lower_unique_idx
  on public.users (lower(trim(nickname)))
  where nickname is not null and trim(nickname) <> '';

-- 가입 전·자동 닉네임 생성용 (anon 허용 — 캠퍼스 앱 닉네임 중복 확인)
create or replace function public.is_nickname_taken(p_nickname text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.users u
    where lower(trim(u.nickname)) = lower(trim(p_nickname))
  );
$$;

revoke all on function public.is_nickname_taken(text) from public;
grant execute on function public.is_nickname_taken(text) to anon, authenticated;
