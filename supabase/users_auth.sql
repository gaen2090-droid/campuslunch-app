-- 회원 테이블 (public.users) + Supabase Auth 연동
-- 실제 DB에는 profiles 가 없고 users 가 있습니다.
-- Dashboard → SQL Editor → Run (한 번만)

-- 카카오/프로필 확장 컬럼
alter table public.users
  add column if not exists kakao_user_id text,
  add column if not exists avatar_url text;

create index if not exists users_email_idx on public.users (email)
  where email is not null;

create index if not exists users_kakao_user_id_idx on public.users (kakao_user_id)
  where kakao_user_id is not null;

-- RLS (users 테이블)
alter table public.users enable row level security;

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own" on public.users
  for select to authenticated
  using (auth.uid() = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own" on public.users
  for insert to authenticated
  with check (auth.uid() = id);

-- auth.users 가입/소셜 로그인 시 public.users 자동 생성
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id,
    email,
    nickname,
    role,
    provider,
    kakao_user_id,
    avatar_url,
    last_login_at
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'nickname', '사용자'),
    coalesce(
      case
        when new.raw_user_meta_data ->> 'role' in ('user', 'owner', 'admin')
        then (new.raw_user_meta_data ->> 'role')::public.user_role
        else 'user'::public.user_role
      end,
      'user'::public.user_role
    ),
    coalesce(
      new.raw_user_meta_data ->> 'auth_provider',
      new.raw_app_meta_data ->> 'provider',
      'email'
    ),
    new.raw_user_meta_data ->> 'kakao_user_id',
    new.raw_user_meta_data ->> 'avatar_url',
    now()
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, users.email),
    nickname = coalesce(excluded.nickname, users.nickname),
    provider = coalesce(excluded.provider, users.provider),
    kakao_user_id = coalesce(excluded.kakao_user_id, users.kakao_user_id),
    avatar_url = coalesce(excluded.avatar_url, users.avatar_url),
    last_login_at = now(),
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 이미 auth.users 에만 있고 public.users 에 없는 계정 백필
insert into public.users (id, email, nickname, role, provider, last_login_at)
select
  au.id,
  au.email,
  coalesce(au.raw_user_meta_data ->> 'nickname', '사용자'),
  'user'::public.user_role,
  coalesce(au.raw_app_meta_data ->> 'provider', 'email'),
  now()
from auth.users au
where not exists (select 1 from public.users u where u.id = au.id);
