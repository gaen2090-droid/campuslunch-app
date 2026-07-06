-- 커뮤니티 공지사항 (Dashboard → SQL Editor → Run)
-- 관리자 작성, 앱은 활성 공지 중 최신 1건만 커뮤니티 탭 최상단에 표시.

create table if not exists public.community_notices (
  id         uuid primary key default gen_random_uuid(),
  content    text not null check (char_length(content) between 1 and 300),
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.community_notices enable row level security;

drop policy if exists "notices read active or admin" on public.community_notices;
create policy "notices read active or admin" on public.community_notices
  for select to authenticated using (is_active or public.is_admin());

drop policy if exists "notices admin write" on public.community_notices;
create policy "notices admin write" on public.community_notices
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
