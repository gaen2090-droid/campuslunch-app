-- 사장님 공지 (Dashboard → SQL Editor → Run)
-- 관리자(웹어드민) 작성, 앱 '사장님 제보' 탭 상단에 활성 공지 중 최신 1건 표시.
-- community_notices 와 분리한 이유: 구버전 앱은 community_notices 를 필터 없이 읽어
-- 커뮤니티 탭에 그대로 노출하므로, 같은 테이블에 섞으면 사장님 공지가 유저에게 보인다.

create table if not exists public.owner_notices (
  id         uuid primary key default gen_random_uuid(),
  content    text not null check (char_length(content) between 1 and 300),
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.owner_notices enable row level security;

drop policy if exists "owner notices read active or admin" on public.owner_notices;
create policy "owner notices read active or admin" on public.owner_notices
  for select to authenticated using (is_active or public.is_admin());

drop policy if exists "owner notices admin write" on public.owner_notices;
create policy "owner notices admin write" on public.owner_notices
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
