-- 닉네임 중복 방지 (대소문자·앞뒤 공백 무시)
-- Dashboard → SQL Editor → Run (rpc_nickname_available.sql 이후)
--
-- '탈퇴한 회원'은 delete_own_account() RPC가 모든 탈퇴자에게 공통으로 부여하는
-- 고정 표시값이라 유니크 검사 대상에서 제외한다 (두 번째 탈퇴자부터
-- duplicate key value violates unique constraint 로 탈퇴 RPC 자체가 실패했었음).

drop index if exists public.users_nickname_lower_unique_idx;

create unique index if not exists users_nickname_lower_unique_idx
  on public.users (lower(trim(nickname)))
  where nickname is not null
    and trim(nickname) <> ''
    and lower(trim(nickname)) <> '탈퇴한 회원';

-- 가입 전·자동 닉네임 생성용 (anon 허용 — 캠퍼스 앱 닉네임 중복 확인)
-- is_reserved_nickname()은 rpc_nickname_available.sql(#6, 이 파일보다 먼저 실행)에서 정의.
create or replace function public.is_nickname_taken(p_nickname text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_reserved_nickname(p_nickname)
    or exists (
      select 1
      from public.users u
      where lower(trim(u.nickname)) = lower(trim(p_nickname))
    );
$$;

revoke all on function public.is_nickname_taken(text) from public;
grant execute on function public.is_nickname_taken(text) to anon, authenticated;
